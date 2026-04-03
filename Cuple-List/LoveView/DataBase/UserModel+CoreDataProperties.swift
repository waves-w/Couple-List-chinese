//
//  UserModel+CoreDataProperties.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
public import Foundation
public import CoreData


public typealias UserModelCoreDataPropertiesSet = NSSet

extension UserModel {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserModel> {
        return NSFetchRequest<UserModel>(entityName: "UserModel")
    }

    @NSManaged public var birthday: Date?
    @NSManaged public var creationDate: Date?
    @NSManaged public var deviceModel: String?
    @NSManaged public var gender: String?
    @NSManaged public var id: String?
    @NSManaged public var isInitiator: Bool
    @NSManaged public var isInLinkedState: Bool
    @NSManaged public var userName: String?
    @NSManaged public var avatarImageURL: String?
    /// 在一起/纪念日起始日（与生日 birthday 分开存储与同步）
    @NSManaged public var relationshipStartDate: Date?

}
