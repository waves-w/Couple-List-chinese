//
//  ListModel+CoreDataProperties.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
public import Foundation
public import CoreData


public typealias ListModelCoreDataPropertiesSet = NSSet

extension ListModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ListModel> {
        return NSFetchRequest<ListModel>(entityName: "ListModel")
    }

    @NSManaged public var assignIndex: Int32
    @NSManaged public var creationDate: Date?
    @NSManaged public var id: String?
    @NSManaged public var isAllDay: Bool
    @NSManaged public var isCompleted: Bool
    @NSManaged public var isReminderOn: Bool
    @NSManaged public var notesLabel: String?
    @NSManaged public var points: Int32
    @NSManaged public var taskDate: Date?
    @NSManaged public var timeString: String?
    @NSManaged public var titleLabel: String?

}
