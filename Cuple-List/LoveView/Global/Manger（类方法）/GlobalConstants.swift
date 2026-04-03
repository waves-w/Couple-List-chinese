//
//  GlobalConstants.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

// MARK: - 任务分配索引 全局常量（核心！统一0/1/2定义）
// ✅ 修复：0=给对方（伴侣），1=给自己（自己），2=双方
enum TaskAssignIndex: Int {
    case partner = 0     // ✅ 修复：给对方（伴侣）
    case myself = 1       // ✅ 修复：给自己（自己）
    case both = 2         // 双方
}

// 快速判断扩展
extension Int {
    var isMyself: Bool { self == TaskAssignIndex.myself.rawValue }
    var isPartner: Bool { self == TaskAssignIndex.partner.rawValue }
    var isBoth: Bool { self == TaskAssignIndex.both.rawValue }
}
