import Foundation

enum AssetKind: Int16, CaseIterable {
    case account = 0
    case realEstate = 1
    case cryptoWallet = 2
    case depositWallet = 3
    case other = 99

    var title: String {
        switch self {
        case .account: return "계좌"
        case .realEstate: return "부동산"
        case .cryptoWallet: return "코인"
        case .depositWallet: return "예적금"
        case .other: return "기타"
        }
    }
}

enum InstrumentKind: Int16, CaseIterable {
    case cash = 0
    case stock = 1
    case crypto = 2
    case deposit = 3
    case realEstate = 4
    case other = 99

    var title: String {
        switch self {
        case .cash: return "현금"
        case .stock: return "주식"
        case .crypto: return "코인"
        case .deposit: return "예적금"
        case .realEstate: return "부동산"
        case .other: return "기타"
        }
    }
}

enum AssetGroupingDimension: Int16, CaseIterable {
    case byAccount = 0
    case byAssetClass = 1
}

struct HoldingDelta {
    let assetID: UUID
    let instrumentCode: String
    let instrumentMarket: String?
    let instrumentKind: InstrumentKind
    let quantityChange: NSDecimalNumber
}

