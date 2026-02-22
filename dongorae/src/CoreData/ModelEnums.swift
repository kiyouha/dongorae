import Foundation

enum LegDirection: Int16, CaseIterable {
    case out = 0
    case `in` = 1
}

enum TransactionType: Int16, CaseIterable, Identifiable {
    case income = 0
    case expense = 1
    case transfer = 2
    case exchange = 3
    case buy = 4
    case sell = 5
    case dividend = 6
    case move = 7
    case positionIn = 8
    case positionOut = 9

    var id: Int16 { rawValue }

    var title: String {
        switch self {
        case .income: return "수입"
        case .expense: return "지출"
        case .transfer: return "이체"
        case .exchange: return "환전"
        case .buy: return "매수"
        case .sell: return "매도"
        case .dividend: return "배당"
        case .move: return "이관"
        case .positionIn: return "입고"
        case .positionOut: return "출고"
        }
    }
}

enum LegRole: Int16, CaseIterable {
    case expense = 0
    case income = 1
    case positionIn = 20
    case positionOut = 21

    var title: String {
        switch self {
        case .expense: return "지출"
        case .income: return "수입"
        case .positionIn: return "입고"
        case .positionOut: return "출고"
        }
    }

    var fixedDirection: LegDirection? {
        switch self {
        case .expense, .positionOut:
            return .out
        case .income, .positionIn:
            return .in
        }
    }
}

enum TagKind: Int16, CaseIterable {
    case category = 0
    case purpose = 1
    case owner = 2
    case status = 3
}
