import Foundation

struct CurrencyDefinition: Codable, Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let symbol: String
    let fractionDigits: Int
}

struct InstitutionDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let assetClass: String
}

enum CurrencyCatalog {
    static let items: [CurrencyDefinition] = {
        if let decoded: [CurrencyDefinition] = ReferenceDataLoader.decodeJSON(named: "currencies") {
            return decoded
                .map { CurrencyDefinition(code: $0.code.uppercased(), name: $0.name, symbol: $0.symbol, fractionDigits: $0.fractionDigits) }
                .sorted { $0.code < $1.code }
        }
        return [
            CurrencyDefinition(code: "KRW", name: "원", symbol: "₩", fractionDigits: 0),
            CurrencyDefinition(code: "USD", name: "미국 달러", symbol: "$", fractionDigits: 2),
            CurrencyDefinition(code: "JPY", name: "일본 엔", symbol: "¥", fractionDigits: 0),
            CurrencyDefinition(code: "EUR", name: "유로", symbol: "€", fractionDigits: 2)
        ]
    }()

    static var codes: [String] {
        items.map(\.code)
    }
}

enum InstitutionCatalog {
    static let items: [InstitutionDefinition] = {
        if let decoded: [InstitutionDefinition] = ReferenceDataLoader.decodeJSON(named: "institutions") {
            return decoded.sorted { $0.name < $1.name }
        }
        return [
            InstitutionDefinition(id: "kb", name: "국민은행", assetClass: "bank"),
            InstitutionDefinition(id: "samsung-sec", name: "삼성증권", assetClass: "brokerage")
        ]
    }()

    static func names(forAssetClass rawAssetClass: Int16) -> [String] {
        let targetClass: String
        switch rawAssetClass {
        case 0: targetClass = "bank"
        case 1: targetClass = "brokerage"
        default: targetClass = "all"
        }

        return items
            .filter { $0.assetClass == targetClass || $0.assetClass == "all" }
            .map(\.name)
            .sorted()
    }
}

private enum ReferenceDataLoader {
    static func decodeJSON<T: Decodable>(named fileName: String) -> T? {
        guard let data = loadData(named: fileName) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func loadData(named fileName: String) -> Data? {
        let candidates: [(String?, String)] = [
            (nil, fileName),
            ("ReferenceData", fileName),
            ("Resources", fileName),
            ("Resources/ReferenceData", fileName)
        ]

        for (subdir, name) in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: subdir) {
                return try? Data(contentsOf: url)
            }
        }
        return nil
    }
}
