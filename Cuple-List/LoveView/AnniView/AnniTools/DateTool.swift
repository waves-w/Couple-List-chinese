//
//  DateTool.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation

class DateTool {
    // 单例
    static let shared = DateTool()
    private init() {}
    
    /// 计算两个日期的剩余天数（保留小数，精确到小时）
    func remainingDays(from startDate: Date, to endDate: Date) -> Double {
        let timeInterval = endDate.timeIntervalSince(startDate)
        return timeInterval / (24 * 60 * 60) // 转换为天数
    }
    
    /// 获取当天0点的时间戳（用于定时刷新）
    func getTodayMidnightTimestamp() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 0
        components.minute = 0
        components.second = 0
        guard let midnight = calendar.date(from: components) else {
            return now.timeIntervalSince1970
        }
        return midnight.timeIntervalSince1970
    }
    
    /// 计算距离下一个0点的时间间隔（用于设置Timer）
    func timeIntervalToNextMidnight() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        tomorrowComponents.day! += 1
        tomorrowComponents.hour = 0
        tomorrowComponents.minute = 0
        tomorrowComponents.second = 0
        guard let tomorrowMidnight = calendar.date(from: tomorrowComponents) else {
            return 24 * 60 * 60 // 默认24小时
        }
        return tomorrowMidnight.timeIntervalSince(now)
    }
}
