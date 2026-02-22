//
//  TransactionCategory+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 22..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TransactionCategoryCoreDataPropertiesSet = NSSet

extension TransactionCategory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionCategory> {
        return NSFetchRequest<TransactionCategory>(entityName: "TransactionCategory")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var order: Int16
    @NSManaged public var title: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var children: NSSet?
    @NSManaged public var parent: TransactionCategory?
    @NSManaged public var transactions: NSSet?

}

// MARK: Generated accessors for children
extension TransactionCategory {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: TransactionCategory)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: TransactionCategory)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)

}

// MARK: Generated accessors for transactions
extension TransactionCategory {

    @objc(addTransactionsObject:)
    @NSManaged public func addToTransactions(_ value: Transaction)

    @objc(removeTransactionsObject:)
    @NSManaged public func removeFromTransactions(_ value: Transaction)

    @objc(addTransactions:)
    @NSManaged public func addToTransactions(_ values: NSSet)

    @objc(removeTransactions:)
    @NSManaged public func removeFromTransactions(_ values: NSSet)

}

extension TransactionCategory : Identifiable {

}
