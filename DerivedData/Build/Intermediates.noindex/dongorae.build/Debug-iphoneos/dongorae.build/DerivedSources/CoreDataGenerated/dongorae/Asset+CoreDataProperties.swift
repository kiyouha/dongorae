//
//  Asset+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 19..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias AssetCoreDataPropertiesSet = NSSet

extension Asset {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Asset> {
        return NSFetchRequest<Asset>(entityName: "Asset")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isActive: Bool
    @NSManaged public var name: String?
    @NSManaged public var note: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var balances: NSSet?
    @NSManaged public var legs: NSSet?
    @NSManaged public var tags: NSSet?

}

// MARK: Generated accessors for balances
extension Asset {

    @objc(addBalancesObject:)
    @NSManaged public func addToBalances(_ value: AssetBalance)

    @objc(removeBalancesObject:)
    @NSManaged public func removeFromBalances(_ value: AssetBalance)

    @objc(addBalances:)
    @NSManaged public func addToBalances(_ values: NSSet)

    @objc(removeBalances:)
    @NSManaged public func removeFromBalances(_ values: NSSet)

}

// MARK: Generated accessors for legs
extension Asset {

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
extension Asset {

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: AssetTag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: AssetTag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)

}

extension Asset : Identifiable {

}
