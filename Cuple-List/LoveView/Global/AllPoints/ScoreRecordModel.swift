//
//  ScoreRecordModel.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

/// ✅ 单条分数变动明细模型（记录每一次加减分）
class ScoreRecordModel: NSObject {
    // 基础属性
    var recordId: String = UUID().uuidString // 明细唯一ID
    var coupleId: String = ""                // 情侣ID（关联）
    var targetUserId: String = ""            // 被奖惩用户UUID（核心：仅作用于指定用户）
    var taskId: String = ""                  // 关联任务ID
    var taskTitle: String = ""               // 关联任务标题
    var taskNotes: String = ""               // 关联任务备注
    var taskSetTime: Date = Date()           // 任务设置的截止时间
    var taskFinishTime: Date = Date()        // 任务实际完成时间
    
    // 分数核心
    var score: Int = 0                       // 分数值（正数=加分，负数=扣分）
    var isOnTime: Bool = true                // 是否按时完成（true=加分，false=扣分）
    
    // 时间戳
    var createTime: Date = Date()            // 分数变动创建时间
    
    /// 模型转Firebase字典
    func toDict() -> [String: Any] {
        return [
            "recordId": recordId,
            "coupleId": coupleId,
            "targetUserId": targetUserId,
            "taskId": taskId,
            "taskTitle": taskTitle,
            "taskNotes": taskNotes,
            "taskSetTime": Timestamp(date: taskSetTime),
            "taskFinishTime": Timestamp(date: taskFinishTime),
            "score": score,
            "isOnTime": isOnTime,
            "createTime": Timestamp(date: createTime)
        ]
    }
    
    /// Firebase字典转模型【强化兜底】
    static func modelFromDict(_ dict: [String: Any]) -> ScoreRecordModel {
        let model = ScoreRecordModel()
        model.recordId = dict["recordId"] as? String ?? UUID().uuidString
        model.coupleId = dict["coupleId"] as? String ?? ""
        model.targetUserId = dict["targetUserId"] as? String ?? ""
        model.taskId = dict["taskId"] as? String ?? ""
        model.taskTitle = dict["taskTitle"] as? String ?? ""
        model.taskNotes = dict["taskNotes"] as? String ?? ""
        
        if let time = dict["taskSetTime"] as? Timestamp { model.taskSetTime = time.dateValue() }
        if let time = dict["taskFinishTime"] as? Timestamp { model.taskFinishTime = time.dateValue() }
        
        model.score = dict["score"] as? Int ?? 0
        model.isOnTime = dict["isOnTime"] as? Bool ?? true
        
        if let time = dict["createTime"] as? Timestamp { model.createTime = time.dateValue() }
        return model
    }
}

/// ✅ 用户总分数模型（记录两人各自总分数）
class UserTotalScoreModel: NSObject {
    var userId: String = ""         // 用户UUID
    var coupleId: String = ""       // 情侣ID
    var totalScore: Int = 0         // 累计总分数（兜底≥0）
    var createTime: Date = Date()   // 创建时间
    var updateTime: Date = Date()   // 更新时间
    
    func toDict() -> [String: Any] {
        return [
            "userId": userId,
            "coupleId": coupleId,
            "totalScore": totalScore,
            "createTime": Timestamp(date: createTime),
            "updateTime": Timestamp(date: updateTime)
        ]
    }
    
    /// Firebase字典转模型【强化兜底】
    static func modelFromDict(_ dict: [String: Any]) -> UserTotalScoreModel {
        let model = UserTotalScoreModel()
        model.userId = dict["userId"] as? String ?? ""
        model.coupleId = dict["coupleId"] as? String ?? ""
        model.totalScore = dict["totalScore"] as? Int ?? 0
        
        if let time = dict["createTime"] as? Timestamp { model.createTime = time.dateValue() }
        if let time = dict["updateTime"] as? Timestamp { model.updateTime = time.dateValue() }
        return model
    }
}
