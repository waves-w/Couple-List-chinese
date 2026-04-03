//
//  AnniDateCalculator.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

/// 纪念日日期&重复计算器（全局复用，封装所有日期计算逻辑）
class AnniDateCalculator {
    static let shared = AnniDateCalculator()
    private init() {}
    
    /// 核心方法：根据原始日期+重复规则，计算【下次目标日期】
    /// - Parameters:
    ///   - originalDate: 创建时的原始日期
    ///   - repeatText: 重复文本（Every 1 Day / Every 1 Year 等）
    /// - Returns: 下次需要纪念的日期（≥今天）
    func calculateNextTargetDate(originalDate: Date, repeatText: String) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let normalizedNow = calendar.startOfDay(for: now)
        var nextDate = calendar.startOfDay(for: originalDate)
        
        // 解析重复规则（格式：Every {number} {unit}）
        let components = repeatText.components(separatedBy: " ")
        guard components.count >= 4,
              let number = Int(components[1]),
              number > 0 else { return originalDate }
        let unit = components[2].lowercased()
        
        // 循环叠加周期，直到找到≥今天的日期
        while nextDate < normalizedNow {
            switch unit {
            case "day":
                nextDate = calendar.date(byAdding: .day, value: number, to: nextDate)!
            case "week":
                nextDate = calendar.date(byAdding: .weekOfYear, value: number, to: nextDate)!
            case "month":
                nextDate = calendar.date(byAdding: .month, value: number, to: nextDate)!
            case "year":
                nextDate = calendar.date(byAdding: .year, value: number, to: nextDate)!
            default:
                return originalDate
            }
        }
        return nextDate
    }
    
    /// ✅ 修复核心：计算「目标日期」与「今天」的【绝对间隔天数】（关键改动）
    /// - 返回值：纯正数，数值越小 → 距离今天越近（无正负，统一排序标准）
    func calculateAbsDaysInterval(targetDate: Date) -> Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: targetDate)
        let interval = calendar.dateComponents([.day], from: target, to: now).day ?? 0
        return abs(interval) // 核心：取绝对值，消除过去/未来的正负差异
    }
    
    /// 格式化显示天数（补0为3位，如：1→001、10→010）
    func formatDays(_ days: Int) -> String {
        return String(format: "%03d", abs(days))
    }
    
    /// ✅ 解析 advanceDate 字符串，计算通知的实际触发时间
    /// - Parameters:
    ///   - advanceDate: 提前通知字符串（"No reminder" / "02:30 PM" / "2 days 3 hr 15 min PM"）
    ///   - targetDate: 目标日期（纪念日日期）
    /// - Returns: 通知触发时间，如果 advanceDate 是 "No reminder" 则返回 nil
    func calculateNotificationTriggerDate(advanceDate: String, targetDate: Date) -> Date? {
        guard advanceDate != "No reminder" else {
            return nil
        }
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: targetDate)
        
        // 格式1: "02:30 PM" - That day 模式，当天指定时间
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "hh:mm a"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let timeDate = timeFormatter.date(from: advanceDate) {
            // 解析出时间（小时和分钟）
            let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
            var triggerComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
            triggerComponents.hour = timeComponents.hour
            triggerComponents.minute = timeComponents.minute
            return calendar.date(from: triggerComponents)
        }
        
        // 格式2: "2 days 3:15,PM" - In advance 模式，提前通知
        // 解析格式：{days} day(s) {hour}:{minute},{period}
        let components = advanceDate.components(separatedBy: " ")
        var days = 0
        var hour = 0
        var minute = 0
        var period = "AM"
        
        var i = 0
        while i < components.count {
            let comp = components[i]
            
            // 解析天数：格式 "2 day" 或 "2 days"
            if (comp == "day" || comp == "days") && i > 0 {
                if let dayValue = Int(components[i - 1]) {
                    days = dayValue
                }
            }
            
            // 解析时间 "3:15,PM" 或 "3:15,AM"（时间部分和AM/PM在同一字符串中）
            if comp.contains(":") && comp.contains(",") {
                let parts = comp.components(separatedBy: ",")
                if parts.count == 2 {
                    // 解析时间部分 "3:15"
                    let timeComponents = parts[0].components(separatedBy: ":")
                    if timeComponents.count == 2,
                       let h = Int(timeComponents[0]),
                       let m = Int(timeComponents[1]) {
                        hour = h
                        minute = m
                    }
                    // 解析AM/PM部分
                    period = parts[1].uppercased()
                }
            }
            
            i += 1
        }
        
        // 转换为24小时制
        if period == "PM" && hour != 12 {
            hour += 12
        } else if period == "AM" && hour == 12 {
            hour = 0
        }
        
        // 计算触发时间 = 目标日期 - 提前天数 + 指定时间
        guard let baseDate = calendar.date(byAdding: .day, value: -days, to: targetDay) else {
            return targetDay
        }
        
        var triggerComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        triggerComponents.hour = hour
        triggerComponents.minute = minute
        return calendar.date(from: triggerComponents)
    }
}
