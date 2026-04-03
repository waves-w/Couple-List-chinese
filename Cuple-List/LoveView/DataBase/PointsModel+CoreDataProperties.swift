//
//  PointsModel+CoreDataProperties.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
public import Foundation
public import CoreData


public typealias PointsModelCoreDataPropertiesSet = NSSet

extension PointsModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PointsModel> {
        return NSFetchRequest<PointsModel>(entityName: "PointsModel")
    }

    @NSManaged public var creationDate: Date?
    @NSManaged public var id: String?
    @NSManaged public var isShared: Bool
    @NSManaged public var notesLabel: String?
    @NSManaged public var points: Int32
    @NSManaged public var titleLabel: String?
    @NSManaged public var userImageData: Data?
    @NSManaged public var wishImage: String?

}
