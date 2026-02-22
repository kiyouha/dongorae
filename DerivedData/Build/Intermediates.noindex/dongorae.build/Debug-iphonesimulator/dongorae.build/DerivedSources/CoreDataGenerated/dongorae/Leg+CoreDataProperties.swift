//
//  Leg+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 20..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias LegCoreDataPropertiesSet = NSSet

extension Leg {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Leg> {
        return NSFetchRequest<Leg>(entityName: "Leg")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var direction: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var note: String?
    @NSManaged public var order: Int16
    @NSManaged public var role: Int16
    @NSManaged public var updatedAt: Date?
    @NSManaged public var asset: Asset?
    @NSManaged public var transaction: Transaction?

}

extension Leg : Identifiable {

}
