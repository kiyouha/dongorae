import CoreData

struct CoreDataTransactionRepository: TransactionRepository {
    func fetchMonth(in context: NSManagedObjectContext, month: Date) throws -> [Transaction] {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? month
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: false),
            NSSortDescriptor(key: "order", ascending: true)
        ]
        return try context.fetch(request)
    }

    func create(in context: NSManagedObjectContext) -> Transaction {
        Transaction(context: context)
    }

    func delete(_ transaction: Transaction, in context: NSManagedObjectContext) {
        context.delete(transaction)
    }
}

struct CoreDataAssetRepository: AssetRepository {
    func fetchAll(in context: NSManagedObjectContext) throws -> [Asset] {
        let request: NSFetchRequest<Asset> = Asset.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return try context.fetch(request)
    }

    func createAccount(in context: NSManagedObjectContext) -> Account {
        Account(context: context)
    }

    func delete(_ asset: Asset, in context: NSManagedObjectContext) {
        context.delete(asset)
    }
}

struct CoreDataTagRepository: TagRepository {
    func findOrCreate(name: String, kind: TagKind, in context: NSManagedObjectContext) throws -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "name ==[c] %@", trimmed)
        if let existing = try context.fetch(request).first {
            existing.updatedAt = Date()
            return existing
        }

        let now = Date()
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = trimmed
        tag.kindEnum = kind
        tag.colorHex = "6ABF9E"
        tag.createdAt = now
        tag.updatedAt = now
        return tag
    }
}

