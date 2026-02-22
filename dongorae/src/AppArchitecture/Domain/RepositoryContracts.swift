import CoreData

protocol TransactionRepository {
    func fetchMonth(in context: NSManagedObjectContext, month: Date) throws -> [Transaction]
    func create(in context: NSManagedObjectContext) -> Transaction
    func delete(_ transaction: Transaction, in context: NSManagedObjectContext)
}

protocol AssetRepository {
    func fetchAll(in context: NSManagedObjectContext) throws -> [Asset]
    func createAccount(in context: NSManagedObjectContext) -> Account
    func delete(_ asset: Asset, in context: NSManagedObjectContext)
}

protocol TagRepository {
    func findOrCreate(name: String, kind: TagKind, in context: NSManagedObjectContext) throws -> Tag
}

