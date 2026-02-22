import CoreData

protocol AppStore {
    func save(_ context: NSManagedObjectContext) throws
    func performBackgroundSave(_ work: @escaping (NSManagedObjectContext) throws -> Void) throws
}

struct CoreDataAppStore: AppStore {
    let container: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.container = container
    }

    func save(_ context: NSManagedObjectContext) throws {
        try CoreDataSaveCoordinator.save(context)
    }

    func performBackgroundSave(_ work: @escaping (NSManagedObjectContext) throws -> Void) throws {
        let context = container.newBackgroundContext()
        var thrown: Error?
        context.performAndWait {
            do {
                try work(context)
                try CoreDataSaveCoordinator.save(context)
            } catch {
                context.rollback()
                thrown = error
            }
        }
        if let thrown {
            throw thrown
        }
    }
}

