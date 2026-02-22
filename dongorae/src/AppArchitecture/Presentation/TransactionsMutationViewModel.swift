import CoreData
import Foundation

@MainActor
final class TransactionsMutationViewModel: ObservableObject {
    @Published var saveErrorMessage: String?

    func create(input: TransactionEditorInput, in context: NSManagedObjectContext, store: any AppStore) -> Bool {
        runInBackgroundStore(mainContext: context, store: store) { background in
            let useCase = TransactionMutationUseCase(context: background)
            try useCase.create(input: input)
        }
    }

    func update(_ tx: Transaction, input: TransactionEditorInput, in context: NSManagedObjectContext, store: any AppStore) -> Bool {
        let objectID = tx.objectID
        return runInBackgroundStore(mainContext: context, store: store) { background in
            guard let bgTx = try background.existingObject(with: objectID) as? Transaction else {
                throw NSError(domain: "TransactionsMutationViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "수정할 거래를 찾을 수 없습니다."])
            }
            let useCase = TransactionMutationUseCase(context: background)
            try useCase.update(bgTx, input: input)
        }
    }

    func delete(_ tx: Transaction, in context: NSManagedObjectContext, store: any AppStore) {
        let objectID = tx.objectID
        _ = runInBackgroundStore(mainContext: context, store: store) { background in
            guard let bgTx = try background.existingObject(with: objectID) as? Transaction else {
                throw NSError(domain: "TransactionsMutationViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "삭제할 거래를 찾을 수 없습니다."])
            }
            let useCase = TransactionMutationUseCase(context: background)
            try useCase.delete(bgTx)
        }
    }

    @discardableResult
    func save(in context: NSManagedObjectContext, store: any AppStore) -> Bool {
        do {
            try store.save(context)
            context.processPendingChanges()
            context.refreshAllObjects()
            return true
        } catch {
            context.rollback()
            saveErrorMessage = CoreDataSaveCoordinator.message(for: error)
            return false
        }
    }

    private func runInBackgroundStore(
        mainContext: NSManagedObjectContext,
        store: any AppStore,
        mutation: @escaping (NSManagedObjectContext) throws -> Void
    ) -> Bool {
        do {
            try store.performBackgroundSave { background in
                background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                background.undoManager = nil
                try mutation(background)
            }
            mainContext.performAndWait {
                mainContext.processPendingChanges()
                mainContext.refreshAllObjects()
            }
            return true
        } catch {
            saveErrorMessage = CoreDataSaveCoordinator.message(for: error)
#if DEBUG
            print("[TransactionsMutationViewModel] background save failed:\n\(saveErrorMessage ?? "")")
#endif
            return false
        }
    }
}
