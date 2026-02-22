//
//  Event+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 20..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias EventCoreDataPropertiesSet = NSSet

extension Event {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var note: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var title: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var tags: NSSet?
    @NSManaged public var transactions: NSSet?

}

// MARK: Generated accessors for tags
extension Event {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: EventTag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: EventTag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

// MARK: Generated accessors for transactions
extension Event {

    @objc(addTransactionsObject:)
    @NSManaged public func addToTransactions(_ value: Transaction)

    @objc(removeTransactionsObject:)
    @NSManaged public func removeFromTransactions(_ value: Transaction)

    @objc(addTransactions:)
    @NSManaged public func addToTransactions(_ values: NSSet)

    @objc(removeTransactions:)
    @NSManaged public func removeFromTransactions(_ values: NSSet)

}

extension Event : Identifiable {

}
