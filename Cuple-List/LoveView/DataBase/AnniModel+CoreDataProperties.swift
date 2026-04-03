//
//  AnniModel+CoreDataProperties.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
public import Foundation
public import CoreData


public typealias AnniModelCoreDataPropertiesSet = NSSet

extension AnniModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AnniModel> {
        return NSFetchRequest<AnniModel>(entityName: "AnniModel")
    }

    @NSManaged public var advanceDate: String?
    @NSManaged public var assignIndex: Int32
    @NSManaged public var creationDate: Date?
    @NSManaged public var creatorUUID: String?
    @NSManaged public var id: String?
    @NSManaged public var isNever: Bool
    @NSManaged public var isReminder: Bool
    /// 是否与伴侣同步到 Firestore；关闭则仅本地 Core Data
    @NSManaged public var isShared: Bool
    @NSManaged public var repeatDate: String?
    @NSManaged public var targetDate: Date?
    @NSManaged public var titleLabel: String?
    @NSManaged public var useraddImage: Data?
    @NSManaged public var wishImage: String?

}
