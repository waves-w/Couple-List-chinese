//
//  AnniNotificationManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import UserNotifications

class AnniNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AnniNotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        // ✅ 移除初始化时的自动权限请求，权限请求已移至引导页 AllowView
        // 1. 设置通知代理，监听「通知触发/点击」事件（核心：触发后补创建下一个）
        notificationCenter.delegate = self
    }
    
    // MARK: 1. 申请通知权限
    func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已授权")
            } else {
                print("❌ 通知权限被拒绝：\(error?.localizedDescription ?? "未知错误")")
            }
        }
    }
    
    // MARK: ✅ 核心方法【单通知创建】- 仅创建「下一个周期」的1条通知（根治无限创建）
    func createSingleCycleTaskNotification(
        taskId: String,
        title: String,
        body: String,
        triggerDate: Date,
        isAllDay: Bool,
        repeatText: String,
        isReminderOn: Bool
    ) {
        guard isReminderOn else {
            print("ℹ️ 任务[\(taskId)]提醒关闭，不创建通知")
            return
        }
        
        // 1. 解析重复规则
        let cycle = TaskRepeatCycle.parse(from: repeatText)
        let cycleCount = TaskRepeatCycle.parseCycleCount(from: repeatText)
        guard cycle != .never else {
            print("ℹ️ 任务[\(taskId)]无重复规则，创建单次通知")
            createSingleNotification(taskId: taskId, title: title, body: body, triggerDate: triggerDate, isAllDay: isAllDay)
            return
        }
        
        // 2. 仅创建「下一个触发时间」的1条通知（核心：单次只创建1条）
        createSingleNotification(taskId: taskId, title: title, body: body, triggerDate: triggerDate, isAllDay: isAllDay)
        print("✅ 任务[\(taskId)]已创建【下一个周期】单条通知，触发时间：\(triggerDate)")
    }
    
    // MARK: ✅ 内部方法 - 创建「单条」通知（带唯一性校验，杜绝重复创建）
    private func createSingleNotification(
        taskId: String,
        title: String,
        body: String,
        triggerDate: Date,
        isAllDay: Bool
    ) {
        // 1. 生成唯一通知ID（任务ID + 下一个触发日期字符串，保证唯一性）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmm" // 精确到分钟，避免同一天重复创建
        let dateStr = dateFormatter.string(from: triggerDate)
        let notificationId = "Cuple_Anni_\(taskId)_\(dateStr)"
        
        // 2. 唯一性校验：已存在则直接跳过（杜绝重复创建）
        notificationCenter.isNotificationExist(withId: notificationId) { [weak self] exist in
            guard let self = self, !exist else {
                print("ℹ️ 通知[\(notificationId)]已存在，跳过创建（安全校验通过）")
                return
            }
            
            // 3. 构建通知内容
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            // ✅ 移除固定 badge = 1，改为使用角标管理器统一管理
            
            // 4. 构建触发条件（全天/指定时间）
            let trigger: UNNotificationTrigger
            if isAllDay {
                let dateComp = Calendar.current.dateComponents([.year, .month, .day], from: triggerDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComp, repeats: false)
            } else {
                let dateComp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComp, repeats: false)
            }
            
            // 5. 添加通知到系统
            let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
            self.notificationCenter.add(request) { error in
                if let error = error {
                    print("❌ 创建单条通知失败[\(notificationId)]：\(error.localizedDescription)")
                } else {
                    print("✅ 单条通知创建成功[\(notificationId)]，仅创建1条，无安全隐患")
                    // ✅ 通知创建成功后，更新角标数量
                    BadgeManager.shared.updateBadgeCount()
                }
            }
        }
    }
    
    // MARK: ✅ 核心方法【检测补建】- 检查任务是否有「待触发通知」，无则补创建下一个
    func checkAndCreateNextNotification(for taskId: String) {
        guard let model = AnniManger.manager.fetchAnniModels().first(where: { $0.id == taskId }) else {
            print("❌ 检测补建失败：未找到任务[\(taskId)]")
            return
        }
        guard model.isReminder else { return }
        
        // 1. 解析规则+当前触发时间
        let currentTriggerDate = model.targetDate ?? Date()
        let cycle = TaskRepeatCycle.parse(from: model.repeatDate ?? "Never")
        let cycleCount = TaskRepeatCycle.parseCycleCount(from: model.repeatDate ?? "Never")
        guard cycle != .never, let nextDate = currentTriggerDate.nextCycleDate(cycle: cycle, count: cycleCount) else {
            return
        }
        
        // 2. 检查该任务是否有「待触发通知」
        let prefix = String.notificationIdPrefix(taskId: taskId)
        notificationCenter.getPendingNotificationRequests { requests in
            let hasPending = requests.filter { $0.identifier.hasPrefix(prefix) }.count > 0
            
            if !hasPending {
                // 无待触发通知 → 补创建「下一个周期」的1条通知
                AnniNotificationManager.shared.createSingleCycleTaskNotification(
                    taskId: taskId,
                    title: model.wishImage ?? "纪念日提醒",
                    body: model.titleLabel ?? "",
                    triggerDate: nextDate,
                    isAllDay: model.isNever,
                    repeatText: model.repeatDate ?? "Never",
                    isReminderOn: model.isReminder
                )
                print("✅ 检测到任务[\(taskId)]无待触发通知，已自动补创建下一个周期通知")
            } else {
                print("ℹ️ 任务[\(taskId)]存在待触发通知，无需补创建")
            }
        }
    }
    
    // MARK: ✅ 通知触发回调（核心闭环）- 通知弹出后，自动补创建「下一个周期」的1条通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let notificationId = response.notification.request.identifier
        // 解析通知ID中的「任务ID」
        if notificationId.hasPrefix("Cuple_Anni_") {
            let components = notificationId.components(separatedBy: "_")
            if components.count >= 3, let taskId = components[2] as String? {
                // 通知触发后 → 立即补创建下一个周期的1条通知（形成闭环）
                checkAndCreateNextNotification(for: taskId)
            }
        }
        completionHandler()
    }
    
    // MARK: 保留原有移除方法（批量移除任务所有通知）
    func removeTaskNotification(taskId: String) {
        let prefix = String.notificationIdPrefix(taskId: taskId)
        notificationCenter.getPendingNotificationRequests { requests in
            let identifiers = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            // ✅ 通知删除后，更新角标数量
            BadgeManager.shared.updateBadgeCount()
        }
        print("✅ 已移除任务的所有待触发通知")
    }
    
    // MARK: 通知在前台显示时的回调
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // ✅ 通知在前台显示时，更新角标数量
        BadgeManager.shared.updateBadgeCount()
        completionHandler([.banner, .sound, .badge])
    }
}
