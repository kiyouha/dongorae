import CoreData
import Foundation

@MainActor
final class TransactionsPageViewModel: ObservableObject {
    @Published var monthCursor: Date = Date()
    @Published var showingSearch = false
    @Published var searchText = ""

    @Published var showingFilter = false
    @Published var selectedAssetOwnerFilters: Set<String> = []
    @Published var selectedAssetClassFilters: Set<String> = []
    @Published var selectedAssetInstitutionFilters: Set<String> = []
    @Published var selectedAssetTagFilters: Set<String> = []
    @Published var selectedTransactionTypeFilters: Set<String> = []
    @Published var selectedTransactionTagFilters: Set<String> = []

    @Published var showingMonthPicker = false
    @Published var isDeleteSelectionMode = false
    @Published var selectedTransactionIDs: Set<NSManagedObjectID> = []
    @Published var transactionViewMode: TransactionViewMode = .list

    func toggleSearch() {
        showingSearch.toggle()
        if !showingSearch { searchText = "" }
    }

    func toggleDeleteSelectionMode() {
        isDeleteSelectionMode.toggle()
        if !isDeleteSelectionMode { selectedTransactionIDs = [] }
    }

    func finishDeleteSelectionMode() {
        isDeleteSelectionMode = false
        selectedTransactionIDs = []
    }

    func toggleTransactionSelection(_ id: NSManagedObjectID) {
        if selectedTransactionIDs.contains(id) {
            selectedTransactionIDs.remove(id)
        } else {
            selectedTransactionIDs.insert(id)
        }
    }
}

