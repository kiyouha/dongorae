import Foundation

struct TransactionsFilterSnapshot {
    let selectedAssetOwners: Set<String>
    let selectedAssetClasses: Set<String>
    let selectedAssetInstitutions: Set<String>
    let selectedAssetTags: Set<String>
    let selectedTransactionTypes: Set<String>
    let selectedTransactionTags: Set<String>
}

enum TransactionsQueryService {
    static func monthTransactions(
        _ transactions: [Transaction],
        monthCursor: Date
    ) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter { tx in
            let baseDate = tx.date ?? tx.executionDate
            guard let baseDate else { return true }
            return calendar.isDate(baseDate, equalTo: monthCursor, toGranularity: .month)
        }
    }

    static func filteredTransactions(
        _ transactions: [Transaction],
        searchText: String,
        filters: TransactionsFilterSnapshot,
        searchableText: (Transaction) -> String,
        assetOwnerNames: (Transaction) -> Set<String>,
        assetClassNames: (Transaction) -> Set<String>,
        assetInstitutionNames: (Transaction) -> Set<String>,
        assetTagNames: (Transaction) -> Set<String>,
        transactionTypeName: (Transaction) -> String,
        transactionTagNames: (Transaction) -> [String]
    ) -> [Transaction] {
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return transactions.filter { tx in
            if !normalizedQuery.isEmpty {
                let searchable = searchableText(tx).lowercased()
                if !searchable.contains(normalizedQuery) { return false }
            }

            if !matchesFilter(candidateNames: assetOwnerNames(tx), selectedNames: filters.selectedAssetOwners) { return false }
            if !matchesFilter(candidateNames: assetClassNames(tx), selectedNames: filters.selectedAssetClasses) { return false }
            if !matchesFilter(candidateNames: assetInstitutionNames(tx), selectedNames: filters.selectedAssetInstitutions) { return false }
            if !matchesFilter(candidateNames: assetTagNames(tx), selectedNames: filters.selectedAssetTags) { return false }
            if !matchesFilter(candidateNames: Set([transactionTypeName(tx)]), selectedNames: filters.selectedTransactionTypes) { return false }
            if !matchesFilter(candidateNames: Set(transactionTagNames(tx)), selectedNames: filters.selectedTransactionTags) { return false }
            return true
        }
    }

    static func groupedByDay(_ transactions: [Transaction]) -> [(day: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: transactions) { tx in
            calendar.startOfDay(for: tx.date ?? .distantPast)
        }

        return groups.keys.sorted(by: >).map { day in
            let items = (groups[day] ?? []).sorted {
                if $0.order != $1.order { return $0.order < $1.order }
                let l = $0.updatedAt ?? $0.createdAt ?? $0.date ?? .distantPast
                let r = $1.updatedAt ?? $1.createdAt ?? $1.date ?? .distantPast
                return l > r
            }
            return (day: day, transactions: items)
        }
    }

    private static func matchesFilter(candidateNames: Set<String>, selectedNames: Set<String>) -> Bool {
        guard !selectedNames.isEmpty else { return true }
        return !candidateNames.isDisjoint(with: selectedNames)
    }
}
