//
//  NotificationCycleTools.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import UserNotifications

// MARK: 1. 重复周期枚举（与你的RepeatPopup完全对应）
enum TaskRepeatCycle: String {
    case never = "Never"
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    /// 从RepeatPopup的选中文本解析周期类型
    static func parse(from repeatText: String) -> TaskRepeatCycle {
        if repeatText.contains("Day") { return .day }
        if repeatText.contains("Week") { return .week }
        if repeatText.contains("Month") { return .month }
        if repeatText.contains("Year") { return .year }
        return .never
    }
    
    /// 解析周期数值（如 "Every 3 Day" → 返回3）
    static func parseCycleCount(from repeatText: String) -> Int {
        let components = repeatText.components(separatedBy: .whitespaces)
        for comp in components {
            if let num = Int(comp) { return num }
        }
        return 1 // 默认1个周期
    }
}

// MARK: 2. 日期扩展 - 快速计算下一个周期日期
extension Date {
    /// 根据周期类型+周期数，计算下一个重复日期
    func nextCycleDate(cycle: TaskRepeatCycle, count: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        
        switch cycle {
        case .day: components.day = count
        case .week: components.weekOfYear = count
        case .month: components.month = count
        case .year: components.year = count
        case .never: return nil
        }
        return calendar.date(byAdding: components, to: self)
    }
}

// MARK: 3. 通知ID生成规则（核心：保证唯一性，解决重复创建问题）
extension String {
    /// 生成唯一通知ID：任务ID + 触发时间戳（精准避免重复）
    static func uniqueNotificationId(taskId: String, triggerDate: Date) -> String {
        let timeStamp = "\(Int(triggerDate.timeIntervalSince1970))"
        return "Cuple_Anni_\(taskId)_\(timeStamp)"
    }
    
    /// 生成任务的「通知ID前缀」（用于批量移除某任务的所有通知）
    static func notificationIdPrefix(taskId: String) -> String {
        return "Cuple_Anni_\(taskId)_"
    }
}

// MARK: 4. 通知中心扩展 - 校验通知是否已存在（核心去重逻辑）
extension UNUserNotificationCenter {
    /// 检查指定ID的通知是否已存在
    func isNotificationExist(withId identifier: String, completion: @escaping (Bool) -> Void) {
        self.getPendingNotificationRequests { requests in
            let exist = requests.contains { $0.identifier == identifier }
            completion(exist)
        }
    }
    
    /// 批量移除某任务的所有通知（根据前缀匹配）
    func removeAllNotifications(for taskId: String) {
        let prefix = String.notificationIdPrefix(taskId: taskId)
        self.getPendingNotificationRequests { requests in
            let identifiers = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            self.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}
