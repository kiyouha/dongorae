import CoreData
import Foundation

struct HoldingRebuildUseCase {
    let context: NSManagedObjectContext
    let baseCurrency: String

    init(context: NSManagedObjectContext, baseCurrency: String = "KRW") {
        self.context = context
        self.baseCurrency = baseCurrency
    }

    func rebuildAll() throws {
        guard hasValuationEntities else { return }

        try clearAllHoldings()

        let request: NSFetchRequest<Leg> = Leg.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true),
            NSSortDescriptor(key: "order", ascending: true)
        ]
        let legs = try context.fetch(request)

        for leg in legs {
            try apply(leg: leg)
        }

        try recalculateValuation()
    }

    func rebuild(forAssetObjectIDs assetIDs: Set<NSManagedObjectID>) throws {
        guard hasValuationEntities else { return }
        guard !assetIDs.isEmpty else { return }

        let assets: [Asset] = assetIDs.compactMap { try? context.existingObject(with: $0) as? Asset }
        guard !assets.isEmpty else { return }

        try clearHoldings(for: assets)

        let request: NSFetchRequest<Leg> = Leg.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true),
            NSSortDescriptor(key: "order", ascending: true)
        ]
        request.predicate = NSPredicate(format: "asset IN %@", assets)
        let legs = try context.fetch(request)

        for leg in legs {
            try apply(leg: leg)
        }

        try recalculateValuation()
    }

    private var hasValuationEntities: Bool {
        let entities = context.persistentStoreCoordinator?.managedObjectModel.entitiesByName ?? [:]
        return entities["Holding"] != nil && entities["Instrument"] != nil
    }

    private func clearAllHoldings() throws {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Holding")
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        _ = try context.execute(delete)
    }

    private func clearHoldings(for assets: [Asset]) throws {
        let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Holding")
        fetch.predicate = NSPredicate(format: "asset IN %@", assets)
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        _ = try context.execute(delete)
    }

    private func apply(leg: Leg) throws {
        guard let asset = leg.asset else { return }

        if let cash = leg as? CashLeg {
            let currency = normalizedCurrency(cash.currency)
            let instrument = try upsertInstrument(
                kind: InstrumentKind.cash,
                code: currency,
                market: nil,
                quoteCurrency: currency,
                displayName: currency
            )
            let holding = try upsertHolding(asset: asset, instrument: instrument)

            let amount = cash.amount ?? NSDecimalNumber.zero
            let signed = leg.directionEnum == .in ? amount : amount.multiplying(by: -1)
            let current = decimalValue(holding, key: "quantity")
            holding.setValue(current.adding(signed), forKey: "quantity")
            holding.setValue(Date(), forKey: "updatedAt")
            return
        }

        if let pos = leg as? PositionLeg {
            let ticker = normalizedTicker(pos.ticker)
            guard !ticker.isEmpty else { return }
            let market = trimmed(pos.market)
            let instrument = try upsertInstrument(
                kind: inferredInstrumentKind(for: pos),
                code: ticker,
                market: market,
                quoteCurrency: txCurrency(leg.transaction),
                displayName: ticker
            )
            let holding = try upsertHolding(asset: asset, instrument: instrument)

            let qty = pos.quantity ?? NSDecimalNumber.zero
            let signedQty = leg.directionEnum == .in ? qty : qty.multiplying(by: -1)
            let prevQty = decimalValue(holding, key: "quantity")
            let newQty = prevQty.adding(signedQty)
            holding.setValue(newQty, forKey: "quantity")

            // 매수(in)이고 단가가 있을 때 가중 평균 단가를 갱신한다.
            if leg.directionEnum == .in, let price = pos.price, qty.compare(NSDecimalNumber.zero) == .orderedDescending {
                let prevAvg = decimalValue(holding, key: "avgCost")
                let prevCost = prevQty.multiplying(by: prevAvg)
                let addCost = qty.multiplying(by: price)
                let nextQty = prevQty.adding(qty)
                if nextQty.compare(NSDecimalNumber.zero) == .orderedDescending {
                    holding.setValue(prevCost.adding(addCost).dividing(by: nextQty), forKey: "avgCost")
                }
            }

            holding.setValue(Date(), forKey: "updatedAt")
        }
    }

    private func recalculateValuation() throws {
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "Holding")
        let holdings = try context.fetch(fetch)

        for holding in holdings {
            guard
                let instrument = holding.value(forKey: "instrument") as? NSManagedObject
            else { continue }

            let kindRaw = (instrument.value(forKey: "kind") as? Int16) ?? InstrumentKind.other.rawValue
            let kind = InstrumentKind(rawValue: kindRaw) ?? .other
            let qty = decimalValue(holding, key: "quantity")

            let quoteCurrency = normalizedCurrency(instrument.value(forKey: "quoteCurrency") as? String)
            let marketValue: NSDecimalNumber
            let lastPrice: NSDecimalNumber?

            switch kind {
            case .cash:
                marketValue = qty
                lastPrice = NSDecimalNumber(value: 1)
            default:
                let code = trimmed(instrument.value(forKey: "code") as? String) ?? ""
                let market = trimmed(instrument.value(forKey: "market") as? String)
                if !code.isEmpty,
                   let point = try latestPricePoint(code: code, market: market),
                   let price = point.value(forKey: "price") as? NSDecimalNumber {
                    marketValue = qty.multiplying(by: price)
                    lastPrice = price
                } else {
                    let avg = decimalValue(holding, key: "avgCost")
                    marketValue = qty.multiplying(by: avg)
                    lastPrice = avg.compare(NSDecimalNumber.zero) == .orderedSame ? nil : avg
                }
            }

            let fx = try fxRate(from: quoteCurrency, to: baseCurrency)
            let baseValue = marketValue.multiplying(by: fx)

            if let lastPrice { holding.setValue(lastPrice, forKey: "lastPrice") }
            holding.setValue(marketValue, forKey: "marketValue")
            holding.setValue(baseValue, forKey: "baseValue")
            holding.setValue(Date(), forKey: "asOf")
            holding.setValue(Date(), forKey: "updatedAt")
        }
    }

    private func upsertInstrument(
        kind: InstrumentKind,
        code: String,
        market: String?,
        quoteCurrency: String?,
        displayName: String?
    ) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Instrument")
        request.fetchLimit = 1
        if let market, !market.isEmpty {
            request.predicate = NSPredicate(format: "kind == %d AND code == %@ AND market == %@", kind.rawValue, code, market)
        } else {
            request.predicate = NSPredicate(format: "kind == %d AND code == %@ AND market == nil", kind.rawValue, code)
        }

        if let existing = try context.fetch(request).first {
            existing.setValue(Date(), forKey: "updatedAt")
            return existing
        }

        let object = NSEntityDescription.insertNewObject(forEntityName: "Instrument", into: context)
        let now = Date()
        object.setValue(UUID(), forKey: "id")
        object.setValue(kind.rawValue, forKey: "kind")
        object.setValue(code, forKey: "code")
        object.setValue(market, forKey: "market")
        object.setValue(displayName, forKey: "name")
        object.setValue(quoteCurrency, forKey: "quoteCurrency")
        object.setValue(true, forKey: "isActive")
        object.setValue(now, forKey: "createdAt")
        object.setValue(now, forKey: "updatedAt")
        return object
    }

    private func upsertHolding(asset: Asset, instrument: NSManagedObject) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Holding")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "asset == %@ AND instrument == %@", asset, instrument)

        if let existing = try context.fetch(request).first {
            return existing
        }

        let object = NSEntityDescription.insertNewObject(forEntityName: "Holding", into: context)
        let now = Date()
        object.setValue(UUID(), forKey: "id")
        object.setValue(asset, forKey: "asset")
        object.setValue(instrument, forKey: "instrument")
        object.setValue(NSDecimalNumber.zero, forKey: "quantity")
        object.setValue(now, forKey: "updatedAt")
        return object
    }

    private func latestPricePoint(code: String, market: String?) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "PricePoint")
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "asOf", ascending: false)]
        if let market, !market.isEmpty {
            request.predicate = NSPredicate(format: "instrumentCode == %@ AND market == %@", code, market)
        } else {
            request.predicate = NSPredicate(format: "instrumentCode == %@ AND market == nil", code)
        }
        return try context.fetch(request).first
    }

    private func fxRate(from source: String, to target: String) throws -> NSDecimalNumber {
        let s = normalizedCurrency(source)
        let t = normalizedCurrency(target)
        if s == t { return NSDecimalNumber(value: 1) }

        let request = NSFetchRequest<NSManagedObject>(entityName: "FxRatePoint")
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "asOf", ascending: false)]
        request.predicate = NSPredicate(format: "baseCurrency == %@ AND quoteCurrency == %@", s, t)
        if let point = try context.fetch(request).first,
           let rate = point.value(forKey: "rate") as? NSDecimalNumber,
           rate.compare(NSDecimalNumber.zero) == .orderedDescending {
            return rate
        }
        return NSDecimalNumber(value: 1)
    }

    private func inferredInstrumentKind(for position: PositionLeg) -> InstrumentKind {
        let unit = normalizedUnit(position.unit)
        if unit == "coin" { return .crypto }
        return .stock
    }

    private func txCurrency(_ tx: Transaction?) -> String {
        guard let tx else { return baseCurrency }
        guard tx.entity.attributesByName["baseCurrency"] != nil else {
            return normalizedCurrency(baseCurrency)
        }
        let value = (tx.value(forKey: "baseCurrency") as? String) ?? baseCurrency
        return normalizedCurrency(value)
    }

    private func decimalValue(_ object: NSManagedObject, key: String) -> NSDecimalNumber {
        (object.value(forKey: key) as? NSDecimalNumber) ?? NSDecimalNumber.zero
    }

    private func normalizedCurrency(_ value: String?) -> String {
        let trimmed = (value ?? "KRW").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.isEmpty ? "KRW" : trimmed
    }

    private func normalizedTicker(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func normalizedUnit(_ value: String?) -> String {
        (value ?? "share").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
