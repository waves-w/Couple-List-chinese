//
//  ListModel+Overdue.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation

// 扩展 ListModel，直接添加逾期判断方法
extension ListModel {
    /// 判断任务是否逾期：未完成 + 截止日期已过
    var isOverdue: Bool {
        guard let taskDate = self.taskDate else { return false } // 无截止日期则不逾期
        let currentDate = Date()
        // 逾期条件：未完成 + 当前时间 > 截止时间
        return !self.isCompleted && currentDate > taskDate
    }
}

// 全局日期工具方法（可选，统一格式化）
class DateUtils {
    static let shared = DateUtils()
    
    /// 格式化日期（统一样式）
    func formatTaskDate(_ date: Date?) -> String {
        guard let date = date else { return "NO Time" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd HH:mm" // 可自定义格式
        return formatter.string(from: date)
    }
}
