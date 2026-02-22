//
//  TransactionTag+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 20..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TransactionTagCoreDataPropertiesSet = NSSet

extension TransactionTag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionTag> {
        return NSFetchRequest<TransactionTag>(entityName: "TransactionTag")
    }

    @NSManaged public var tag: Tag?
    @NSManaged public var transaction: Transaction?

}

extension TransactionTag : Identifiable {

}
