//
//  Tag+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 20..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TagCoreDataPropertiesSet = NSSet

extension Tag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var colorHex: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var kind: Int16
    @NSManaged public var name: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var assetTags: NSSet?
    @NSManaged public var eventTags: NSSet?
    @NSManaged public var transactionTags: NSSet?

}

// MARK: Generated accessors for assetTags
extension Tag {

    @objc(addAssetTagsObject:)
    @NSManaged public func addToAssetTags(_ value: AssetTag)

    @objc(removeAssetTagsObject:)
    @NSManaged public func removeFromAssetTags(_ value: AssetTag)

    @objc(addAssetTags:)
    @NSManaged public func addToAssetTags(_ values: NSSet)

    @objc(removeAssetTags:)
    @NSManaged public func removeFromAssetTags(_ values: NSSet)

}

// MARK: Generated accessors for eventTags
extension Tag {

    @objc(addEventTagsObject:)
    @NSManaged public func addToEventTags(_ value: EventTag)

    @objc(removeEventTagsObject:)
    @NSManaged public func removeFromEventTags(_ value: EventTag)

    @objc(addEventTags:)
    @NSManaged public func addToEventTags(_ values: NSSet)

    @objc(removeEventTags:)
    @NSManaged public func removeFromEventTags(_ values: NSSet)

}

// MARK: Generated accessors for transactionTags
extension Tag {

    @objc(addTransactionTagsObject:)
    @NSManaged public func addToTransactionTags(_ value: TransactionTag)

    @objc(removeTransactionTagsObject:)
    @NSManaged public func removeFromTransactionTags(_ value: TransactionTag)

    @objc(addTransactionTags:)
    @NSManaged public func addToTransactionTags(_ values: NSSet)

    @objc(removeTransactionTags:)
    @NSManaged public func removeFromTransactionTags(_ values: NSSet)

}

extension Tag : Identifiable {

}
