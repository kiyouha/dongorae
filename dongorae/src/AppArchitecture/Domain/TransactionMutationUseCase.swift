import CoreData

struct TransactionMutationUseCase {
    let context: NSManagedObjectContext

    func create(input: TransactionEditorInput) throws {
        let tx = Transaction(context: context)
        tx.id = UUID()
        apply(input: input, to: tx)
        try rebuildHoldingsIfPossible(affectedAssetIDs: affectedAssetIDs(of: tx))
    }

    func update(_ tx: Transaction, input: TransactionEditorInput) throws {
        let beforeAssetIDs = affectedAssetIDs(of: tx)
        apply(input: input, to: tx)
        let afterAssetIDs = affectedAssetIDs(of: tx)
        try rebuildHoldingsIfPossible(affectedAssetIDs: beforeAssetIDs.union(afterAssetIDs))
    }

    func delete(_ tx: Transaction) throws {
        let beforeAssetIDs = affectedAssetIDs(of: tx)
        context.delete(tx)
        try rebuildHoldingsIfPossible(affectedAssetIDs: beforeAssetIDs)
    }

    private func apply(input: TransactionEditorInput, to tx: Transaction) {
        let now = Date()
        tx.id = tx.id ?? UUID()
        if tx.createdAt == nil { tx.createdAt = now }
        tx.updatedAt = now
        tx.date = input.date
        tx.executionDate = input.executionDate
        setValueIfPropertyExists(on: tx, key: "category", value: category(from: input.categoryID))

        let isStockType = isStockTransactionType(input.transactionType)
        let normalizedTicker = trimmedOrNil(input.stockTicker)?.uppercased()
        let normalizedMarket = trimmedOrNil(input.stockMarket)?.uppercased()

        setValueIfAttributeExists(on: tx, key: "fxRate", value: input.transactionType == .exchange ? inferredExchangeRate(from: input.legs) : nil)
        setValueIfAttributeExists(on: tx, key: "averagePrice", value: (input.transactionType == .buy || input.transactionType == .sell) ? inferredAveragePrice(from: input.legs, type: input.transactionType) : nil)
        setValueIfAttributeExists(on: tx, key: "ticker", value: isStockType ? normalizedTicker : nil)
        setValueIfAttributeExists(on: tx, key: "market", value: isStockType ? normalizedMarket : nil)
        setValueIfAttributeExists(
            on: tx,
            key: "dividendTicker",
            value: input.transactionType == .dividend
                ? (normalizedTicker ?? trimmedOrNil(input.dividendTicker)?.uppercased())
                : nil
        )
        tx.title = trimmedOrNil(input.transactionTitle)
        tx.memo = trimmedOrNil(input.memo)

        if tx.isInserted {
            tx.order = nextOrder(on: input.date)
        }

        applyTransactionTags(parseCommaList(input.transactionTagsText), to: tx)
        syncLegs(for: tx, drafts: input.legs, transactionType: input.transactionType)
    }

    private func syncLegs(for tx: Transaction, drafts: [LegDraft], transactionType: TransactionType) {
        let now = Date()
        let existingLegs = ((tx.legs as? Set<Leg>) ?? [])
        var existingByID: [NSManagedObjectID: Leg] = [:]
        for leg in existingLegs { existingByID[leg.objectID] = leg }
        let fixedTicker = transactionTicker(tx)
        let fixedMarket = transactionMarket(tx)
        let lockPositionTickerMarket = isStockTransactionType(transactionType)

        var kept: Set<NSManagedObjectID> = []

        for (index, draft) in drafts.enumerated() {
            let leg: Leg
            if let existingID = draft.existingID, let found = existingByID[existingID] {
                leg = found
                kept.insert(existingID)
            } else {
                leg = draft.kind == .cash ? CashLeg(context: context) : PositionLeg(context: context)
                leg.id = UUID()
                leg.createdAt = now
                leg.transaction = tx
            }

            leg.updatedAt = now
            leg.directionEnum = draft.direction
            leg.roleEnum = draft.role
            leg.order = Int16(index)
            setValueIfAttributeExists(on: leg, key: "title", value: trimmedOrNil(draft.titleText))
            setValueIfAttributeExists(on: leg, key: "isRequired", value: draft.isRequired)
            leg.note = nil
            leg.asset = asset(from: draft.assetID) ?? ensureDefaultAsset()

            if let cash = leg as? CashLeg {
                cash.amount = decimal(from: draft.amountText) ?? 0
                let trimmed = draft.currency.trimmingCharacters(in: .whitespacesAndNewlines)
                cash.currency = trimmed.isEmpty ? "KRW" : trimmed
                cash.fxRate = nil
            }

            if let position = leg as? PositionLeg {
                if lockPositionTickerMarket {
                    position.ticker = fixedTicker ?? ""
                    position.market = fixedMarket ?? ""
                } else {
                    position.ticker = trimmedOrNil(draft.ticker) ?? ""
                    position.market = trimmedOrNil(draft.market) ?? ""
                }
                position.quantity = decimal(from: draft.quantityText) ?? 0
                position.price = decimal(from: draft.priceText)
                position.unit = trimmedOrNil(draft.unit) ?? "share"
            }
        }

        for leg in existingLegs where !kept.contains(leg.objectID) {
            context.delete(leg)
        }
    }

    private func applyTransactionTags(_ names: [String], to tx: Transaction) {
        if let existing = tx.tags as? Set<TransactionTag> {
            for join in existing { context.delete(join) }
        }

        for name in Set(names) {
            let join = TransactionTag(context: context)
            join.transaction = tx
            join.tag = findOrCreateTag(named: name)
            setValueIfAttributeExists(on: join, key: "isAuto", value: false)
        }
    }

    private func findOrCreateTag(named name: String) -> Tag {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "name ==[c] %@", trimmedName)

        if let existing = try? context.fetch(request).first {
            existing.updatedAt = Date()
            return existing
        }

        let now = Date()
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = trimmedName
        tag.kindEnum = .category
        tag.colorHex = "6ABF9E"
        tag.createdAt = now
        tag.updatedAt = now
        return tag
    }

    private func parseCommaList(_ text: String) -> [String] {
        let values = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(values)).sorted()
    }

    private func trimmedOrNil(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func decimal(from text: String) -> NSDecimalNumber? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let value = NSDecimalNumber(string: trimmed.replacingOccurrences(of: ",", with: "."))
        if value == NSDecimalNumber.notANumber { return nil }
        return value
    }

    private func inferredExchangeRate(from drafts: [LegDraft]) -> NSDecimalNumber? {
        let cashDrafts = drafts.filter { $0.kind == .cash }
        let outDrafts = cashDrafts.filter { $0.direction == .out }
        let inDrafts = cashDrafts.filter { $0.direction == .in }

        guard
            let out = outDrafts.max(by: { (decimal(from: $0.amountText) ?? 0).doubleValue < (decimal(from: $1.amountText) ?? 0).doubleValue }),
            let input = inDrafts.max(by: { (decimal(from: $0.amountText) ?? 0).doubleValue < (decimal(from: $1.amountText) ?? 0).doubleValue }),
            let outAmount = decimal(from: out.amountText),
            let inAmount = decimal(from: input.amountText),
            inAmount.compare(NSDecimalNumber.zero) == .orderedDescending,
            normalizedCurrency(out.currency) != normalizedCurrency(input.currency)
        else {
            return nil
        }

        return outAmount.dividing(by: inAmount)
    }

    private func inferredAveragePrice(from drafts: [LegDraft], type: TransactionType) -> NSDecimalNumber? {
        guard type == .buy || type == .sell else { return nil }
        let direction: LegDirection = type == .buy ? .in : .out
        let targets = drafts.filter { $0.kind == .position && $0.direction == direction }

        var totalQty: NSDecimalNumber = 0
        var totalAmount: NSDecimalNumber = 0
        for draft in targets {
            guard let qtyRaw = decimal(from: draft.quantityText), let price = decimal(from: draft.priceText) else { continue }
            let qty = qtyRaw.compare(0) == .orderedAscending ? qtyRaw.multiplying(by: -1) : qtyRaw
            guard qty.compare(0) == .orderedDescending else { continue }
            totalQty = totalQty.adding(qty)
            totalAmount = totalAmount.adding(qty.multiplying(by: price))
        }
        guard totalQty.compare(0) == .orderedDescending else { return nil }
        return totalAmount.dividing(by: totalQty)
    }

    private func normalizedCurrency(_ currency: String?) -> String {
        let normalized = (currency ?? "KRW").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? "KRW" : normalized
    }

    private func isStockTransactionType(_ type: TransactionType) -> Bool {
        switch type {
        case .buy, .sell, .dividend, .move, .positionIn, .positionOut:
            return true
        default:
            return false
        }
    }

    private func transactionTicker(_ tx: Transaction) -> String? {
        let ticker = dynamicStringValue(tx, key: "ticker")?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let ticker, !ticker.isEmpty { return ticker }
        return nil
    }

    private func transactionMarket(_ tx: Transaction) -> String? {
        let market = dynamicStringValue(tx, key: "market")?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let market, !market.isEmpty { return market }
        return nil
    }

    private func dynamicStringValue(_ object: NSManagedObject, key: String) -> String? {
        guard object.entity.attributesByName[key] != nil else { return nil }
        return object.value(forKey: key) as? String
    }

    private func setValueIfAttributeExists(on object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName[key] != nil else { return }
        object.setValue(value, forKey: key)
    }

    private func setValueIfPropertyExists(on object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName[key] != nil || object.entity.relationshipsByName[key] != nil else { return }
        object.setValue(value, forKey: key)
    }

    private func asset(from objectID: NSManagedObjectID?) -> Asset? {
        guard let objectID else { return nil }
        return try? context.existingObject(with: objectID) as? Asset
    }

    private func category(from objectID: NSManagedObjectID?) -> NSManagedObject? {
        guard let objectID else { return nil }
        return try? context.existingObject(with: objectID)
    }

    private func ensureDefaultAsset() -> Asset {
        let request: NSFetchRequest<Asset> = Asset.fetchRequest()
        request.fetchLimit = 1
        if let first = try? context.fetch(request).first {
            return first
        }

        let now = Date()
        let account = Account(context: context)
        account.id = UUID()
        account.name = "기본 현금"
        account.note = nil
        account.isActive = true
        account.createdAt = now
        account.updatedAt = now
        account.accountNumber = nil
        account.institution = "수동 생성"
        account.type = 0
        return account
    }

    private func nextOrder(on date: Date) -> Int16 {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: false)]
        request.fetchLimit = 1
        let topOrder = (try? context.fetch(request).first?.order) ?? -1
        return topOrder + 1
    }

    private func rebuildHoldingsIfPossible(affectedAssetIDs: Set<NSManagedObjectID>) throws {
        guard !affectedAssetIDs.isEmpty else { return }
        let useCase = HoldingRebuildUseCase(context: context)
        try useCase.rebuild(forAssetObjectIDs: affectedAssetIDs)
    }

    private func affectedAssetIDs(of tx: Transaction) -> Set<NSManagedObjectID> {
        let legs = (tx.legs as? Set<Leg>) ?? []
        return Set(legs.compactMap { $0.asset?.objectID })
    }
}
