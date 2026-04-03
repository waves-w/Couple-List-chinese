//
//  UUIDManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation

// 用户UUID管理：生成唯一且持久化的用户标识
extension UserDefaults {
    // 存储用户唯一UUID的Key（确保唯一，避免与你现有Key冲突）
    private static let userUniqueUUIDKey = "com.cuple.list.userUniqueUUID"
    
    /// 获取用户唯一UUID（首次调用生成，后续直接读取，永久不变）
    static func getUserUniqueUUID() -> String {
        // 1. 先从本地读取，若存在直接返回
        if let existingUUID = UserDefaults.standard.string(forKey: userUniqueUUIDKey) {
            return existingUUID
        }
        
        // 2. 若不存在，生成新的UUID并持久化存储
        let newUserUUID = UUID().uuidString
        UserDefaults.standard.set(newUserUUID, forKey: userUniqueUUIDKey)
        UserDefaults.standard.synchronize()
        
        print("✅ 首次启动，生成用户唯一UUID：\(newUserUUID)")
        return newUserUUID
    }
}
