//
//  BadgeManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import UserNotifications

/// 角标管理器 - 统一管理应用角标数量
class BadgeManager {
    static let shared = BadgeManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    /// 更新角标数量（基于待处理的通知数量）
    func updateBadgeCount() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            
            // 计算待处理的通知数量
            let badgeCount = requests.count
            
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = badgeCount
                print("✅ 角标已更新：\(badgeCount) 条待处理通知")
            }
        }
    }
    
    /// 清除角标
    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            print("✅ 角标已清除")
        }
    }
    
    /// 设置角标数量（手动设置）
    func setBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = max(0, count)
            print("✅ 角标已设置为：\(count)")
        }
    }
}











