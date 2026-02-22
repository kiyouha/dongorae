import Foundation

enum SummaryTokenStyle {
    case secondary
    case primary
    case positive
    case negative
    case accent
}

struct SummaryToken {
    let text: String
    let style: SummaryTokenStyle
    let leadingSeparator: Bool

    static func secondary(_ text: String, leadingSeparator: Bool = true) -> SummaryToken {
        SummaryToken(text: text, style: .secondary, leadingSeparator: leadingSeparator)
    }

    static func styled(_ text: String, style: SummaryTokenStyle, leadingSeparator: Bool = true) -> SummaryToken {
        SummaryToken(text: text, style: style, leadingSeparator: leadingSeparator)
    }
}

struct TransactionSummaryResult {
    let inferredType: TransactionType
    let tokens: [SummaryToken]
}

enum TransactionSummaryService {
    static func makeSummary(
        tx: Transaction,
        legs: [Leg],
        fxRate: NSDecimalNumber?,
        averagePrice: NSDecimalNumber?,
        dividendTicker: String?,
        amountText: (NSDecimalNumber) -> String,
        decimalText: (NSDecimalNumber) -> String
    ) -> TransactionSummaryResult {
        let cashLegs = legs.compactMap { $0 as? CashLeg }
        let positionLegs = legs.compactMap { $0 as? PositionLeg }
        let inferred = inferType(tx: tx, legs: legs, fxRate: fxRate, dividendTicker: dividendTicker)

        var result: [SummaryToken] = [.secondary(inferred.title, leadingSeparator: false)]

        switch inferred {
        case .income, .expense, .dividend:
            if let cash = preferredCashPart(cashLegs, amountText: amountText) {
                result.append(contentsOf: partTokens(cash))
            }

        case .transfer:
            result.append(contentsOf: arrowTokens(for: cashLegs, amountText: amountText))

        case .exchange:
            result.append(contentsOf: arrowTokens(for: cashLegs, amountText: amountText))
            if let rate = fxRate {
                result.append(.secondary("환율 ", leadingSeparator: true))
                result.append(.styled(amountText(rate), style: .accent, leadingSeparator: false))
            }

        case .buy, .sell:
            if let pos = preferredPositionPart(positionLegs, decimalText: decimalText) {
                result.append(contentsOf: partTokens(pos))
            }
            if let cash = preferredCashPart(cashLegs, amountText: amountText) {
                result.append(contentsOf: partTokens(cash))
            }
            if let averagePrice {
                result.append(.secondary("평단 ", leadingSeparator: true))
                result.append(.styled(amountText(averagePrice), style: .accent, leadingSeparator: false))
            }

        case .move, .positionIn, .positionOut:
            if let pos = preferredPositionPart(positionLegs, showSign: false, decimalText: decimalText) {
                result.append(contentsOf: partTokens(pos))
            }
        }

        if inferred == .dividend,
           let ticker = dividendTicker?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
           !ticker.isEmpty {
            result.append(.secondary(ticker))
        }

        if result.count == 1 {
            result.append(.secondary("요약 없음"))
        }

        return TransactionSummaryResult(inferredType: inferred, tokens: result)
    }

    static func inferType(
        tx: Transaction,
        legs: [Leg],
        fxRate: NSDecimalNumber?,
        dividendTicker: String?
    ) -> TransactionType {
        if fxRate != nil { return .exchange }
        if let ticker = dividendTicker?.trimmingCharacters(in: .whitespacesAndNewlines), !ticker.isEmpty { return .dividend }

        let positionLegs = legs.compactMap { $0 as? PositionLeg }
        let cashLegs = legs.compactMap { $0 as? CashLeg }

        let hasPosIn = positionLegs.contains { $0.directionEnum == .in }
        let hasPosOut = positionLegs.contains { $0.directionEnum == .out }
        let hasCashIn = cashLegs.contains { $0.directionEnum == .in }
        let hasCashOut = cashLegs.contains { $0.directionEnum == .out }

        let inCurrencies = Set(cashLegs.filter { $0.directionEnum == .in }.map { normalizedCurrency($0.currency) })
        let outCurrencies = Set(cashLegs.filter { $0.directionEnum == .out }.map { normalizedCurrency($0.currency) })
        let isExchange = hasCashIn && hasCashOut && inCurrencies.contains { inCode in
            outCurrencies.contains { outCode in inCode != outCode }
        }

        if hasPosIn && hasCashOut && !hasPosOut { return .buy }
        if hasPosOut && hasCashIn && !hasPosIn { return .sell }
        if hasPosIn && hasPosOut { return .move }
        if hasPosIn { return .positionIn }
        if hasPosOut { return .positionOut }
        if isExchange { return .exchange }
        if hasCashIn && hasCashOut { return .transfer }
        if hasCashIn { return .income }
        if hasCashOut { return .expense }
        return .expense
    }

    private struct SummaryPart {
        let label: String
        let signedValue: String
        let signedStyle: SummaryTokenStyle
    }

    private static func preferredCashPart(_ legs: [CashLeg], amountText: (NSDecimalNumber) -> String) -> SummaryPart? {
        compactCashParts(legs, limit: 2, amountText: amountText).first
    }

    private static func preferredPositionPart(
        _ legs: [PositionLeg],
        showSign: Bool = true,
        decimalText: (NSDecimalNumber) -> String
    ) -> SummaryPart? {
        compactPositionParts(legs, limit: 1, showSign: showSign, decimalText: decimalText).first
    }

    private static func compactCashParts(
        _ legs: [CashLeg],
        limit: Int,
        amountText: (NSDecimalNumber) -> String
    ) -> [SummaryPart] {
        guard !legs.isEmpty else { return [] }
        var totals: [String: NSDecimalNumber] = [:]

        for leg in legs {
            let currency = normalizedCurrency(leg.currency)
            let base = leg.amount ?? 0
            let signed = leg.directionEnum == .in ? base : base.multiplying(by: -1)
            totals[currency] = (totals[currency] ?? 0).adding(signed)
        }

        let sorted = totals.sorted {
            abs($0.value.doubleValue) > abs($1.value.doubleValue)
        }

        let limited = sorted.prefix(limit).map { signedCashPart(currency: $0.key, value: $0.value, amountText: amountText) }
        let hidden = max(sorted.count - limit, 0)
        if hidden > 0 {
            return limited + [SummaryPart(label: "+\(hidden)", signedValue: "", signedStyle: .secondary)]
        }
        return limited
    }

    private static func compactPositionParts(
        _ legs: [PositionLeg],
        limit: Int,
        showSign: Bool,
        decimalText: (NSDecimalNumber) -> String
    ) -> [SummaryPart] {
        guard !legs.isEmpty else { return [] }
        var totals: [String: NSDecimalNumber] = [:]

        for leg in legs {
            let symbol = (leg.ticker ?? "-").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let key = symbol.isEmpty ? "-" : symbol
            let quantity = leg.quantity ?? 0
            let signed = leg.directionEnum == .in ? quantity : quantity.multiplying(by: -1)
            totals[key] = (totals[key] ?? 0).adding(signed)
        }

        let sorted = totals.sorted {
            abs($0.value.doubleValue) > abs($1.value.doubleValue)
        }

        let limited = sorted.prefix(limit).map {
            signedPositionPart(ticker: $0.key, value: $0.value, showSign: showSign, decimalText: decimalText)
        }
        let hidden = max(sorted.count - limit, 0)
        if hidden > 0 {
            return limited + [SummaryPart(label: "+\(hidden)", signedValue: "", signedStyle: .secondary)]
        }
        return limited
    }

    private static func arrowTokens(for legs: [CashLeg], amountText: (NSDecimalNumber) -> String) -> [SummaryToken] {
        let outCandidate = legs
            .filter { $0.directionEnum == .out }
            .sorted { ($0.amount ?? 0).doubleValue > ($1.amount ?? 0).doubleValue }
            .first
        let inCandidate = legs
            .filter { $0.directionEnum == .in }
            .sorted { ($0.amount ?? 0).doubleValue > ($1.amount ?? 0).doubleValue }
            .first

        guard let outCandidate, let inCandidate else { return [.secondary("요약 없음")] }

        let outPart = signedCashPart(currency: normalizedCurrency(outCandidate.currency), value: (outCandidate.amount ?? 0).multiplying(by: -1), amountText: amountText)
        let inPart = signedCashPart(currency: normalizedCurrency(inCandidate.currency), value: inCandidate.amount ?? 0, amountText: amountText)

        var tokens = partTokens(outPart)
        tokens.append(.secondary(" → ", leadingSeparator: false))
        tokens.append(contentsOf: partTokens(inPart, leadingSeparator: false))
        return tokens
    }

    private static func signedCashPart(currency: String, value: NSDecimalNumber, amountText: (NSDecimalNumber) -> String) -> SummaryPart {
        let cmp = value.compare(NSDecimalNumber.zero)
        let sign = cmp == .orderedDescending ? "+" : (cmp == .orderedAscending ? "-" : "")
        let absValue = cmp == .orderedAscending ? value.multiplying(by: -1) : value
        let style: SummaryTokenStyle = cmp == .orderedDescending ? .positive : (cmp == .orderedAscending ? .negative : .primary)
        return SummaryPart(
            label: currency,
            signedValue: "\(sign)\(amountText(absValue))",
            signedStyle: style
        )
    }

    private static func signedPositionPart(
        ticker: String,
        value: NSDecimalNumber,
        showSign: Bool,
        decimalText: (NSDecimalNumber) -> String
    ) -> SummaryPart {
        let cmp = value.compare(NSDecimalNumber.zero)
        let sign = cmp == .orderedDescending ? "+" : (cmp == .orderedAscending ? "-" : "")
        let absValue = cmp == .orderedAscending ? value.multiplying(by: -1) : value
        let quantity = decimalText(absValue)
        let style: SummaryTokenStyle = showSign
            ? (cmp == .orderedDescending ? .positive : (cmp == .orderedAscending ? .negative : .primary))
            : .primary
        return SummaryPart(
            label: ticker,
            signedValue: showSign ? "\(sign)\(quantity)주" : "\(quantity)주",
            signedStyle: style
        )
    }

    private static func partTokens(_ part: SummaryPart, leadingSeparator: Bool = true) -> [SummaryToken] {
        if part.signedValue.isEmpty {
            return [.secondary(part.label, leadingSeparator: leadingSeparator)]
        }
        return [
            .secondary("\(part.label) ", leadingSeparator: leadingSeparator),
            .styled(part.signedValue, style: part.signedStyle, leadingSeparator: false)
        ]
    }

    private static func normalizedCurrency(_ currency: String?) -> String {
        let normalized = (currency ?? "KRW").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? "KRW" : normalized
    }
}
