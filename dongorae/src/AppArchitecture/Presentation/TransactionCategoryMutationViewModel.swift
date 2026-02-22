import CoreData
import Foundation

@MainActor
final class TransactionCategoryMutationViewModel: ObservableObject {
    @Published var saveErrorMessage: String?
    @Published var deleteBlockedMessage: String?

    func saveCategory(
        editingID: NSManagedObjectID?,
        input: TransactionCategoryInput,
        existingCategories: [NSManagedObject],
        in parent: NSManagedObjectContext,
        store: any AppStore
    ) {
        _ = runInChildContext(parent: parent, store: store) { child in
            let now = Date()
            let target: NSManagedObject
            if let editingID,
               let existing = try child.existingObject(with: editingID) as? NSManagedObject {
                target = existing
            } else {
                target = NSEntityDescription.insertNewObject(forEntityName: "TransactionCategory", into: child)
            }

            let parentObject: NSManagedObject?
            if let parentID = input.parentID {
                parentObject = try child.existingObject(with: parentID)
            } else {
                parentObject = nil
            }

            if target.value(forKey: "id") == nil {
                target.setValue(UUID(), forKey: "id")
                target.setValue(now, forKey: "createdAt")
                target.setValue(nextOrder(forParentID: input.parentID, in: existingCategories), forKey: "order")
            }
            target.setValue(now, forKey: "updatedAt")
            target.setValue(input.title, forKey: "title")

            if let parentIcon = (parentObject?.value(forKey: "icon") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !parentIcon.isEmpty {
                target.setValue(parentIcon, forKey: "icon")
            } else {
                target.setValue(input.icon, forKey: "icon")
            }

            target.setValue(parentObject, forKey: "parent")
        }
    }

    func deleteCategory(_ categoryID: NSManagedObjectID, in parent: NSManagedObjectContext, store: any AppStore) {
        _ = runInChildContext(parent: parent, store: store) { child in
            guard let category = try child.existingObject(with: categoryID) as? NSManagedObject else {
                throw NSError(domain: "TransactionCategoryMutationViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "삭제할 카테고리를 찾을 수 없습니다."])
            }
            let childCount = ((category.value(forKey: "children") as? Set<NSManagedObject>) ?? []).count
            let txCount = ((category.value(forKey: "transactions") as? Set<NSManagedObject>) ?? []).count
            if childCount > 0 || txCount > 0 {
                throw NSError(domain: "TransactionCategoryMutationViewModel", code: 409, userInfo: [NSLocalizedDescriptionKey: "하위 카테고리 또는 연결된 거래내역이 있어 삭제할 수 없습니다."])
            }
            child.delete(category)
        }
    }

    private func nextOrder(forParentID parentID: NSManagedObjectID?, in categories: [NSManagedObject]) -> Int16 {
        let siblings = categories.filter { item in
            let parent = item.value(forKey: "parent") as? NSManagedObject
            switch (parent?.objectID, parentID) {
            case (nil, nil): return true
            case let (lhs?, rhs?): return lhs == rhs
            default: return false
            }
        }
        let maxOrder = siblings.compactMap { $0.value(forKey: "order") as? Int16 }.max() ?? -1
        return maxOrder + 1
    }

    private func runInChildContext(
        parent: NSManagedObjectContext,
        store: any AppStore,
        mutation: (NSManagedObjectContext) throws -> Void
    ) -> Bool {
        let child = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        child.parent = parent
        child.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        child.undoManager = nil

        var capturedError: Error?

        child.performAndWait {
            do {
                try mutation(child)
                try store.save(child)
            } catch {
                capturedError = error
                child.rollback()
            }
        }

        if let capturedError {
            let message = CoreDataSaveCoordinator.message(for: capturedError)
            if (capturedError as NSError).code == 409 {
                deleteBlockedMessage = message
            } else {
                saveErrorMessage = message
            }
            #if DEBUG
            print("[TransactionCategoryMutationViewModel] save(child) failed:\n\(message)")
            #endif
            return false
        }

        do {
            try store.save(parent)
            parent.processPendingChanges()
            parent.refreshAllObjects()
            return true
        } catch {
            parent.rollback()
            let message = CoreDataSaveCoordinator.message(for: error)
            if (error as NSError).code == 409 {
                deleteBlockedMessage = message
            } else {
                saveErrorMessage = message
            }
            #if DEBUG
            print("[TransactionCategoryMutationViewModel] save(parent) failed:\n\(message)")
            #endif
            return false
        }
    }
}
