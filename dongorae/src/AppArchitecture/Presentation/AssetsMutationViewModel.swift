import CoreData
import Foundation

@MainActor
final class AssetsMutationViewModel: ObservableObject {
    @Published var saveErrorMessage: String?

    func create(input: AssetEditorInput, in context: NSManagedObjectContext, store: any AppStore) -> Bool {
        runInBackgroundStore(mainContext: context, store: store) { background in
            let useCase = AssetMutationUseCase(context: background)
            try useCase.create(input: input)
        }
    }

    func update(_ account: Account, input: AssetEditorInput, in context: NSManagedObjectContext, store: any AppStore) -> Bool {
        let objectID = account.objectID
        return runInBackgroundStore(mainContext: context, store: store) { background in
            guard let bgAccount = try background.existingObject(with: objectID) as? Account else {
                throw NSError(domain: "AssetsMutationViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "수정할 자산을 찾을 수 없습니다."])
            }
            let useCase = AssetMutationUseCase(context: background)
            try useCase.update(bgAccount, input: input)
        }
    }

    func delete(_ asset: Asset, in context: NSManagedObjectContext, store: any AppStore) {
        let objectID = asset.objectID
        _ = runInBackgroundStore(mainContext: context, store: store) { background in
            guard let bgAsset = try background.existingObject(with: objectID) as? Asset else {
                throw NSError(domain: "AssetsMutationViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "삭제할 자산을 찾을 수 없습니다."])
            }
            let useCase = AssetMutationUseCase(context: background)
            try useCase.delete(bgAsset)
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
            print("[AssetsMutationViewModel] background save failed:\n\(saveErrorMessage ?? "")")
#endif
            return false
        }
    }
}
