import CoreData

struct AppContainer {
    let store: AppStore
    let transactionRepository: TransactionRepository
    let assetRepository: AssetRepository
    let tagRepository: TagRepository

    static func live(_ persistentContainer: NSPersistentContainer) -> AppContainer {
        AppContainer(
            store: CoreDataAppStore(container: persistentContainer),
            transactionRepository: CoreDataTransactionRepository(),
            assetRepository: CoreDataAssetRepository(),
            tagRepository: CoreDataTagRepository()
        )
    }
}

