//
//  LocalNotificationManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import UserNotifications

class LocalNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 通知权限申请失败：\(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ 通知权限申请结果：\(granted ? "已授权" : "已拒绝")")
                    completion(granted)
                }
            }
        }
    }
    
    // MARK: ✅ 核心强化 - 新增权限校验兜底+强制日志，确保创建结果可追溯
    func createTaskNotification(
        taskId: String,
        title: String,
        body: String,
        triggerDate: Date,
        isAllDay: Bool,
        isReminderOn: Bool
    ) {
        guard isReminderOn else {
            print("ℹ️ 提醒开关关闭，不创建通知[\(taskId)]")
            return
        }
        
        // ✅ 兜底校验：创建前再次检查权限，无权限则引导开启
        notificationCenter.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("❌ 通知创建失败[\(taskId)]：无通知权限！请引导用户在【设置-通知】开启")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body.isEmpty ? "你有一个待办任务需要处理～" : body
            content.sound = .default
            // ✅ 移除固定 badge = 1，改为使用角标管理器统一管理
            content.userInfo = ["taskId": taskId]
            
            var trigger: UNNotificationTrigger!
            let calendar = Calendar.current
            if isAllDay {
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: triggerDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            } else {
                let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            }
            
            let request = UNNotificationRequest(identifier: taskId, content: content, trigger: trigger)
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("❌ 通知创建失败[\(taskId)]：\(error.localizedDescription)")
                } else {
                    let localFormatter = DateFormatter()
                    localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    localFormatter.timeZone = .current
                    print("✅ ✅ ✅ 通知创建成功[\(taskId)]，本地触发时间：\(localFormatter.string(from: triggerDate)) ✅ ✅ ✅")
                    // ✅ 通知创建成功后，更新角标数量
                    BadgeManager.shared.updateBadgeCount()
                }
            }
        }
    }
    
    func testNotificationNow() {
        let content = UNMutableNotificationContent()
        content.title = "测试通知"
        content.body = "通知配置成功！"
        content.sound = .default
        // ✅ 移除固定 badge = 1，改为使用角标管理器统一管理
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test_noti", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                print("✅ 测试通知已添加，10秒后弹出")
                // ✅ 通知创建成功后，更新角标数量
                BadgeManager.shared.updateBadgeCount()
            }
        }
    }
    
    func removeTaskNotification(taskId: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [taskId])
        print("✅ 已移除任务[\(taskId)]的本地通知")
        // ✅ 通知删除后，更新角标数量
        BadgeManager.shared.updateBadgeCount()
    }
    
    func removeAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("✅ 已移除所有本地通知")
        // ✅ 通知删除后，更新角标数量
        BadgeManager.shared.updateBadgeCount()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let taskId = userInfo["taskId"] as? String {
            print("🔔 点击了任务[\(taskId)]的本地通知")
            NotificationCenter.default.post(name: NSNotification.Name("NotificationClick_TaskDetail"), object: taskId)
        }
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // ✅ 通知在前台显示时，更新角标数量
        BadgeManager.shared.updateBadgeCount()
        completionHandler([.banner, .sound, .badge])
    }
}
