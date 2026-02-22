import CoreData
import Foundation

struct TransactionCategoryEditRoute: Identifiable {
    let id: NSManagedObjectID
}

@MainActor
final class TransactionCategoryPageViewModel: ObservableObject {
    @Published var showingCreate = false
    @Published var editingRoute: TransactionCategoryEditRoute?

    func startCreate() {
        showingCreate = true
    }

    func startEdit(_ objectID: NSManagedObjectID) {
        editingRoute = TransactionCategoryEditRoute(id: objectID)
    }
}

