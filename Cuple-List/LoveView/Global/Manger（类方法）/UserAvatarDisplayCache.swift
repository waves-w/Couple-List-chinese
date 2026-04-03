//
//  UserAvatarDisplayCache.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

/// 单例：存储抠图后的单人/双人头像，key 为头像字符串（或组合键）。收到 UserManger.dataDidUpdateNotification 时清空。
final class UserAvatarDisplayCache {
    static let shared = UserAvatarDisplayCache()
    
    private var singleCache: [String: UIImage] = [:]
    private var combinedCache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.cuple.avatarDisplayCache", attributes: .concurrent)
    
    private init() {}
    private static func combinedKey(partner: String, my: String) -> String {
        let a = partner.prefix(300)
        let b = my.prefix(300)
        return "\(a)|||\(b)"
    }
    
    func imageForSingle(avatarString: String) -> UIImage? {
        guard !avatarString.isEmpty else { return nil }
        return queue.sync { singleCache[avatarString] }
    }
    
    func imageForCombined(partnerAvatar: String, myAvatar: String) -> UIImage? {
        let key = Self.combinedKey(partner: partnerAvatar, my: myAvatar)
        return queue.sync { combinedCache[key] }
    }
    
    func setSingle(_ image: UIImage, for avatarString: String) {
        guard !avatarString.isEmpty else { return }
        queue.async(flags: .barrier) { [weak self] in
            self?.singleCache[avatarString] = image
        }
    }
    
    func setCombined(_ image: UIImage, partnerAvatar: String, myAvatar: String) {
        let key = Self.combinedKey(partner: partnerAvatar, my: myAvatar)
        queue.async(flags: .barrier) { [weak self] in
            self?.combinedCache[key] = image
        }
    }
    
    /// 识别到用户数据修改时调用，清空后各页从 UserManger 重新拉数据并刷新
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.singleCache.removeAll()
            self?.combinedCache.removeAll()
        }
    }
}
