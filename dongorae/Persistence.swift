//
//  Persistence.swift
//  dongorae
//
//  Created by 김영한 on 3/23/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        seedSampleDataIfNeeded(context: viewContext)
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let persistentContainer = NSPersistentContainer(name: "dongorae")
        if inMemory {
            persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        let initialLoadError = Self.loadStores(for: persistentContainer)

        if let error = initialLoadError, !inMemory {
            let shouldResetStore = Self.isIncompatibleMigrationError(error)
            let storeURL = persistentContainer.persistentStoreDescriptions.first?.url

            if shouldResetStore, let storeURL {
                do {
                    try Self.destroySQLiteStore(at: storeURL, coordinator: persistentContainer.persistentStoreCoordinator)
                    if let reloadError = Self.loadStores(for: persistentContainer) {
                        fatalError("Persistent store reload failed after reset: \(reloadError), \(reloadError.userInfo)")
                    }
                } catch {
                    let nsError = error as NSError
                    fatalError("Failed to reset incompatible persistent store: \(nsError), \(nsError.userInfo)")
                }
            } else {
                fatalError("Unresolved persistent store error \(error), \(error.userInfo)")
            }
        } else if let error = initialLoadError, inMemory {
            fatalError("Unresolved in-memory persistent store error \(error), \(error.userInfo)")
        }

        self.container = persistentContainer
        self.container.viewContext.automaticallyMergesChangesFromParent = true
        self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.container.viewContext.undoManager = nil
        self.container.viewContext.shouldDeleteInaccessibleFaults = true
    }

    private static func loadStores(for container: NSPersistentContainer) -> NSError? {
        let group = DispatchGroup()
        let descriptionCount = max(container.persistentStoreDescriptions.count, 1)
        var loadError: NSError?

        for _ in 0..<descriptionCount { group.enter() }
        container.loadPersistentStores { _, error in
            if let nsError = error as NSError? {
                loadError = nsError
            }
            group.leave()
        }
        group.wait()
        return loadError
    }

    private static func isIncompatibleMigrationError(_ error: NSError) -> Bool {
        guard error.domain == NSCocoaErrorDomain else { return false }
        let migrationErrorCodes: Set<Int> = [
            NSPersistentStoreIncompatibleVersionHashError,
            NSMigrationError,
            NSMigrationMissingSourceModelError,
            NSMigrationMissingMappingModelError,
            NSMigrationManagerSourceStoreError,
            NSMigrationCancelledError
        ]
        return migrationErrorCodes.contains(error.code) || error.code == 134110
    }

    private static func destroySQLiteStore(at storeURL: URL, coordinator: NSPersistentStoreCoordinator) throws {
        try coordinator.destroyPersistentStore(at: storeURL, type: .sqlite, options: nil)

        let baseURL = storeURL.deletingPathExtension()
        let shmURL = baseURL.appendingPathExtension("sqlite-shm")
        let walURL = baseURL.appendingPathExtension("sqlite-wal")

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.removeItem(at: shmURL)
        }
        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.removeItem(at: walURL)
        }
    }

    static func seedSampleDataIfNeeded(context: NSManagedObjectContext) {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.fetchLimit = 1

        guard (try? context.count(for: request)) == 0 else { return }

        let now = Date()

        let krwAccount = Account(context: context)
        krwAccount.id = UUID()
        krwAccount.name = "원화 계좌"
        krwAccount.note = nil
        krwAccount.isActive = true
        krwAccount.createdAt = now
        krwAccount.updatedAt = now
        krwAccount.accountNumber = nil
        krwAccount.institution = "국내은행"
        krwAccount.type = 0

        let usdAccount = Account(context: context)
        usdAccount.id = UUID()
        usdAccount.name = "증권 USD 현금"
        usdAccount.note = nil
        usdAccount.isActive = true
        usdAccount.createdAt = now
        usdAccount.updatedAt = now
        usdAccount.accountNumber = nil
        usdAccount.institution = "브로커"
        usdAccount.type = 0

        let stockAccount = Account(context: context)
        stockAccount.id = UUID()
        stockAccount.name = "증권 계좌"
        stockAccount.note = nil
        stockAccount.isActive = true
        stockAccount.createdAt = now
        stockAccount.updatedAt = now
        stockAccount.accountNumber = nil
        stockAccount.institution = "브로커"
        stockAccount.type = 1

        let categoryTag = Tag(context: context)
        categoryTag.id = UUID()
        categoryTag.name = "주식"
        categoryTag.kind = 0
        categoryTag.colorHex = "#2E8B57"
        categoryTag.createdAt = now
        categoryTag.updatedAt = now

        let ownerTag = Tag(context: context)
        ownerTag.id = UUID()
        ownerTag.name = "본인"
        ownerTag.kind = 2
        ownerTag.colorHex = "#1E90FF"
        ownerTag.createdAt = now
        ownerTag.updatedAt = now

        func makeCategory(
            title: String,
            icon: String,
            parent: NSManagedObject?,
            order: Int16
        ) -> NSManagedObject? {
            guard let entity = NSEntityDescription.entity(forEntityName: "TransactionCategory", in: context) else {
                return nil
            }
            let category = NSManagedObject(entity: entity, insertInto: context)
            setValueIfAttributeExists(on: category, key: "id", value: UUID())
            setValueIfAttributeExists(on: category, key: "title", value: title)
            setValueIfAttributeExists(on: category, key: "icon", value: icon)
            setValueIfAttributeExists(on: category, key: "order", value: order)
            setValueIfAttributeExists(on: category, key: "createdAt", value: now)
            setValueIfAttributeExists(on: category, key: "updatedAt", value: now)
            setValueIfAttributeExists(on: category, key: "parent", value: parent)
            return category
        }

        // 샘플 카테고리
        let parentOnlyCategory = makeCategory(title: "생활", icon: "🏠", parent: nil, order: 0)
        let foodParentCategory = makeCategory(title: "식비", icon: "🍽️", parent: nil, order: 1)
        let foodChildCategory = makeCategory(title: "외식", icon: "🍽️", parent: foodParentCategory, order: 0)
        let eightCharCategory = makeCategory(title: "12345678", icon: "🔖", parent: nil, order: 2)

        let tx1 = Transaction(context: context)
        tx1.id = UUID()
        tx1.createdAt = now
        tx1.updatedAt = now
        tx1.date = now
        tx1.executionDate = now
        tx1.title = "환전 후 매수"
        tx1.memo = nil
        setValueIfAttributeExists(on: tx1, key: "fxRate", value: NSDecimalNumber(string: "1330"))
        setValueIfAttributeExists(on: tx1, key: "dividendTicker", value: nil)
        tx1.order = 0

        let tx2 = Transaction(context: context)
        tx2.id = UUID()
        tx2.createdAt = now
        tx2.updatedAt = now
        tx2.date = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now
        tx2.executionDate = nil
        tx2.title = "환율 우대 환급"
        tx2.memo = nil
        setValueIfAttributeExists(on: tx2, key: "fxRate", value: nil)
        setValueIfAttributeExists(on: tx2, key: "dividendTicker", value: nil)
        tx2.order = 1
        setValueIfPropertyExists(on: tx2, key: "category", value: parentOnlyCategory)

        let tx3 = Transaction(context: context)
        tx3.id = UUID()
        tx3.createdAt = now
        tx3.updatedAt = now
        tx3.date = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        tx3.executionDate = nil
        tx3.title = "장보기"
        tx3.memo = nil
        setValueIfAttributeExists(on: tx3, key: "fxRate", value: nil)
        setValueIfAttributeExists(on: tx3, key: "dividendTicker", value: nil)
        tx3.order = 2
        setValueIfPropertyExists(on: tx3, key: "category", value: eightCharCategory)

        let tx1Tag1 = TransactionTag(context: context)
        tx1Tag1.transaction = tx1
        tx1Tag1.tag = categoryTag
        let tx1Tag2 = TransactionTag(context: context)
        tx1Tag2.transaction = tx1
        tx1Tag2.tag = ownerTag

        let tx2Tag1 = TransactionTag(context: context)
        tx2Tag1.transaction = tx2
        tx2Tag1.tag = ownerTag

        let tx3Tag1 = TransactionTag(context: context)
        tx3Tag1.transaction = tx3
        tx3Tag1.tag = ownerTag

        func makeCashLeg(
            tx: Transaction,
            role: LegRole,
            direction: LegDirection,
            order: Int16,
            amount: String,
            currency: String,
            fxRate: String?,
            asset: Asset
        ) {
            let leg = CashLeg(context: context)
            leg.id = UUID()
            leg.createdAt = now
            leg.updatedAt = now
            leg.directionEnum = direction
            leg.roleEnum = role
            leg.order = order
            setValueIfAttributeExists(on: leg, key: "title", value: nil)
            setValueIfAttributeExists(on: leg, key: "isRequired", value: false)
            leg.note = nil
            leg.amount = NSDecimalNumber(string: amount)
            leg.currency = currency
            leg.fxRate = fxRate.map { NSDecimalNumber(string: $0) }
            leg.transaction = tx
            leg.asset = asset
        }

        func makePositionLeg(
            tx: Transaction,
            role: LegRole,
            direction: LegDirection,
            order: Int16,
            ticker: String,
            market: String,
            quantity: String,
            unit: String,
            price: String?,
            asset: Asset
        ) {
            let leg = PositionLeg(context: context)
            leg.id = UUID()
            leg.createdAt = now
            leg.updatedAt = now
            leg.directionEnum = direction
            leg.roleEnum = role
            leg.order = order
            setValueIfAttributeExists(on: leg, key: "title", value: nil)
            setValueIfAttributeExists(on: leg, key: "isRequired", value: false)
            leg.note = nil
            leg.ticker = ticker
            leg.market = market
            leg.quantity = NSDecimalNumber(string: quantity)
            leg.unit = unit
            leg.price = price.map { NSDecimalNumber(string: $0) }
            leg.transaction = tx
            leg.asset = asset
        }

        makeCashLeg(tx: tx1, role: .expense, direction: .out, order: 0, amount: "1330000", currency: "KRW", fxRate: "1330", asset: krwAccount)
        makeCashLeg(tx: tx1, role: .income, direction: .in, order: 1, amount: "1000", currency: "USD", fxRate: nil, asset: usdAccount)
        makeCashLeg(tx: tx1, role: .expense, direction: .out, order: 2, amount: "1000", currency: "USD", fxRate: nil, asset: usdAccount)
        makeCashLeg(tx: tx1, role: .expense, direction: .out, order: 3, amount: "1", currency: "USD", fxRate: nil, asset: usdAccount)
        makePositionLeg(tx: tx1, role: .positionIn, direction: .in, order: 4, ticker: "AAPL", market: "NASDAQ", quantity: "10", unit: "share", price: "100", asset: stockAccount)
        setValueIfPropertyExists(on: tx1, key: "category", value: foodChildCategory)

        makeCashLeg(tx: tx2, role: .income, direction: .in, order: 0, amount: "2", currency: "USD", fxRate: nil, asset: usdAccount)
        makeCashLeg(tx: tx3, role: .expense, direction: .out, order: 0, amount: "32000", currency: "KRW", fxRate: nil, asset: krwAccount)

        try? context.save()
    }

    private static func setValueIfAttributeExists(on object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName[key] != nil else { return }
        object.setValue(value, forKey: key)
    }

    private static func setValueIfPropertyExists(on object: NSManagedObject, key: String, value: Any?) {
        guard object.entity.attributesByName[key] != nil || object.entity.relationshipsByName[key] != nil else { return }
        object.setValue(value, forKey: key)
    }
}
