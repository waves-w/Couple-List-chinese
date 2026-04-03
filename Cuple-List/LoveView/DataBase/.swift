//
//  .swift
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

    @NSManaged public var id: String?
    @NSManaged public var titleLabel: String?
    @NSManaged public var creationDate: Date?
    @NSManaged public var notesLabel: String?

}
