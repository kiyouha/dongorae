//
//  Transaction+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 22..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TransactionCoreDataPropertiesSet = NSSet

extension Transaction {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Transaction> {
        return NSFetchRequest<Transaction>(entityName: "Transaction")
    }

    @NSManaged public var averagePrice: NSDecimalNumber?
    @NSManaged public var date: Date?
    @NSManaged public var dividendTicker: String?
    @NSManaged public var executionDate: Date?
    @NSManaged public var fxRate: NSDecimalNumber?
    @NSManaged public var id: UUID?
    @NSManaged public var market: String?
    @NSManaged public var memo: String?
    @NSManaged public var order: Int16
    @NSManaged public var ticker: String?
    @NSManaged public var title: String?
    @NSManaged public var category: TransactionCategory?
    @NSManaged public var legs: NSSet?
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for legs
extension Transaction {

    @objc(addLegsObject:)
    @NSManaged public func addToLegs(_ value: Leg)

    @objc(removeLegsObject:)
    @NSManaged public func removeFromLegs(_ value: Leg)

    @objc(addLegs:)
    @NSManaged public func addToLegs(_ values: NSSet)

    @objc(removeLegs:)
    @NSManaged public func removeFromLegs(_ values: NSSet)

}

// MARK: Generated accessors for tags
extension Transaction {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: TransactionTag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: TransactionTag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

extension Transaction : Identifiable {

}
