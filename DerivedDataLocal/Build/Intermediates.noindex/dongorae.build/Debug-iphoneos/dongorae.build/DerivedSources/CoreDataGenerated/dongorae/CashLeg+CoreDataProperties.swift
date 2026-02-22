//
//  CashLeg+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 22..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias CashLegCoreDataPropertiesSet = NSSet

extension CashLeg {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CashLeg> {
        return NSFetchRequest<CashLeg>(entityName: "CashLeg")
    }

    @NSManaged public var amount: NSDecimalNumber?
    @NSManaged public var currency: String?
    @NSManaged public var fxRate: NSDecimalNumber?

}
