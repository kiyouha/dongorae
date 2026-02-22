//
//  AssetBalance+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 20..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias AssetBalanceCoreDataPropertiesSet = NSSet

extension AssetBalance {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AssetBalance> {
        return NSFetchRequest<AssetBalance>(entityName: "AssetBalance")
    }

    @NSManaged public var amount: NSDecimalNumber?
    @NSManaged public var currency: String?
    @NSManaged public var id: UUID?
    @NSManaged public var asset: Asset?

}

extension AssetBalance : Identifiable {

}
