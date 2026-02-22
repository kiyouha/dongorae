//
//  EventTag+CoreDataProperties.swift
//  
//
//  Created by 김영한 on 2026. 2. 19..
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias EventTagCoreDataPropertiesSet = NSSet

extension EventTag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EventTag> {
        return NSFetchRequest<EventTag>(entityName: "EventTag")
    }

    @NSManaged public var event: Event?
    @NSManaged public var tag: Tag?

}

extension EventTag : Identifiable {

}
