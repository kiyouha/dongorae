//
//  AssetTag+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 20..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias AssetTagCoreDataPropertiesSet = NSSet

extension AssetTag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AssetTag> {
        return NSFetchRequest<AssetTag>(entityName: "AssetTag")
    }

    @NSManaged public var asset: Asset?
    @NSManaged public var tag: Tag?

}

extension AssetTag : Identifiable {

}
