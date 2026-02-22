//
//  PositionLeg+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 22..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias PositionLegCoreDataPropertiesSet = NSSet

extension PositionLeg {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PositionLeg> {
        return NSFetchRequest<PositionLeg>(entityName: "PositionLeg")
    }

    @NSManaged public var market: String?
    @NSManaged public var price: NSDecimalNumber?
    @NSManaged public var quantity: NSDecimalNumber?
    @NSManaged public var ticker: String?
    @NSManaged public var unit: String?

}
