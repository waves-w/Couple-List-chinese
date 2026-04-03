//
//  PointsViewDataManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import CoreData
import MagicalRecord

class PointsViewDataManager {
    
    // MARK: - 从 CoreData 生成测试数据（用于 Firebase 连接不上时的测试，带去重检查）
    static func generateTestRecordsFromCoreData(
        existingRecords: [ScoreRecordModel],
        completion: @escaping ([ScoreRecordModel]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let allTasks = DbManager.manager.fetchListModels()
            var testRecords: [ScoreRecordModel] = []
            
            let currentUserId = CoupleStatusManager.getUserUniqueUUID()
            let (_, partnerUser) = UserManger.manager.getCoupleUsers()
            let partnerUserId = partnerUser?.id ?? ""
            let coupleId = CoupleStatusManager.getPartnerId() ?? ""
            
            // ✅ 创建现有记录的快速查找集合
            let existingRecordKeys = Set(existingRecords.map { record in
                "\(record.taskId)_\(record.targetUserId)_\(record.score)_\(record.isOnTime)"
            })
            
            for task in allTasks {
                guard let taskId = task.id,
                      task.points > 0 else {
                    continue
                }
                
                let assignIndex = Int(task.assignIndex)
                let taskScore = Int(task.points)
                let taskDate = task.taskDate ?? Date()
                let taskTitle = task.titleLabel ?? "未命名任务"
                let taskNotes = task.notesLabel ?? ""
                
                // ✅ 根据任务完成状态生成记录
                if task.isCompleted {
                    // 已完成：生成加分记录
                    let finishTime = taskDate.addingTimeInterval(-3600) // 假设提前1小时完成
                    let isOnTime = finishTime <= taskDate
                    let finalScore = isOnTime ? taskScore : -taskScore
                    
                    addRecordsForAssignIndex(
                        assignIndex: assignIndex,
                        taskId: taskId,
                        taskTitle: taskTitle,
                        taskNotes: taskNotes,
                        taskSetTime: taskDate,
                        taskFinishTime: finishTime,
                        score: finalScore,
                        isOnTime: isOnTime,
                        currentUserId: currentUserId,
                        partnerUserId: partnerUserId,
                        coupleId: coupleId,
                        existingRecordKeys: existingRecordKeys,
                        records: &testRecords
                    )
                } else {
                    // 未完成但逾期：生成扣分记录
                    let currentDate = Date()
                    if currentDate > taskDate {
                        let finalScore = -taskScore
                        
                        addRecordsForAssignIndex(
                            assignIndex: assignIndex,
                            taskId: taskId,
                            taskTitle: taskTitle,
                            taskNotes: taskNotes,
                            taskSetTime: taskDate,
                            taskFinishTime: currentDate,
                            score: finalScore,
                            isOnTime: false,
                            currentUserId: currentUserId,
                            partnerUserId: partnerUserId,
                            coupleId: coupleId,
                            existingRecordKeys: existingRecordKeys,
                            records: &testRecords
                        )
                    }
                }
            }
            
            // ✅ 按创建时间倒序排序
            testRecords.sort { $0.createTime > $1.createTime }
            
            // ✅ 在主线程返回结果
            DispatchQueue.main.async {
                completion(testRecords)
            }
        }
    }
    
    // MARK: - 根据 assignIndex 添加记录（统一处理所有情况）
    private static func addRecordsForAssignIndex(
        assignIndex: Int,
        taskId: String,
        taskTitle: String,
        taskNotes: String,
        taskSetTime: Date,
        taskFinishTime: Date,
        score: Int,
        isOnTime: Bool,
        currentUserId: String,
        partnerUserId: String,
        coupleId: String,
        existingRecordKeys: Set<String>,
        records: inout [ScoreRecordModel]
    ) {
        switch assignIndex {
        case TaskAssignIndex.partner.rawValue: // 0 = 给对方
            if !partnerUserId.isEmpty {
                addRecordIfNotExists(
                    taskId: taskId,
                    taskTitle: taskTitle,
                    taskNotes: taskNotes,
                    taskSetTime: taskSetTime,
                    taskFinishTime: taskFinishTime,
                    targetUserId: partnerUserId,
                    score: score,
                    isOnTime: isOnTime,
                    coupleId: coupleId,
                    existingRecordKeys: existingRecordKeys,
                    records: &records
                )
            }
        case TaskAssignIndex.myself.rawValue: // 1 = 给自己
            addRecordIfNotExists(
                taskId: taskId,
                taskTitle: taskTitle,
                taskNotes: taskNotes,
                taskSetTime: taskSetTime,
                taskFinishTime: taskFinishTime,
                targetUserId: currentUserId,
                score: score,
                isOnTime: isOnTime,
                coupleId: coupleId,
                existingRecordKeys: existingRecordKeys,
                records: &records
            )
        case TaskAssignIndex.both.rawValue: // 2 = 双方
            // 给自己
            addRecordIfNotExists(
                taskId: taskId,
                taskTitle: taskTitle,
                taskNotes: taskNotes,
                taskSetTime: taskSetTime,
                taskFinishTime: taskFinishTime,
                targetUserId: currentUserId,
                score: score,
                isOnTime: isOnTime,
                coupleId: coupleId,
                existingRecordKeys: existingRecordKeys,
                records: &records
            )
            // 给对方
            if !partnerUserId.isEmpty {
                addRecordIfNotExists(
                    taskId: taskId,
                    taskTitle: taskTitle,
                    taskNotes: taskNotes,
                    taskSetTime: taskSetTime,
                    taskFinishTime: taskFinishTime,
                    targetUserId: partnerUserId,
                    score: score,
                    isOnTime: isOnTime,
                    coupleId: coupleId,
                    existingRecordKeys: existingRecordKeys,
                    records: &records
                )
            }
        default:
            break
        }
    }
    
    // MARK: - 添加记录（如果不存在）
    private static func addRecordIfNotExists(
        taskId: String,
        taskTitle: String,
        taskNotes: String,
        taskSetTime: Date,
        taskFinishTime: Date,
        targetUserId: String,
        score: Int,
        isOnTime: Bool,
        coupleId: String,
        existingRecordKeys: Set<String>,
        records: inout [ScoreRecordModel]
    ) {
        let recordKey = "\(taskId)_\(targetUserId)_\(score)_\(isOnTime)"
        guard !existingRecordKeys.contains(recordKey) else { return }
        
        let record = createTestRecord(
            taskId: taskId,
            taskTitle: taskTitle,
            taskNotes: taskNotes,
            taskSetTime: taskSetTime,
            taskFinishTime: taskFinishTime,
            targetUserId: targetUserId,
            score: score,
            isOnTime: isOnTime,
            coupleId: coupleId
        )
        records.append(record)
    }
    
    // MARK: - 创建测试记录
    private static func createTestRecord(
        taskId: String,
        taskTitle: String,
        taskNotes: String,
        taskSetTime: Date,
        taskFinishTime: Date,
        targetUserId: String,
        score: Int,
        isOnTime: Bool,
        coupleId: String
    ) -> ScoreRecordModel {
        let record = ScoreRecordModel()
        record.recordId = UUID().uuidString
        record.coupleId = coupleId
        record.targetUserId = targetUserId
        record.taskId = taskId
        record.taskTitle = taskTitle
        record.taskNotes = taskNotes
        record.taskSetTime = taskSetTime
        record.taskFinishTime = taskFinishTime
        record.score = score
        record.isOnTime = isOnTime
        record.createTime = taskFinishTime
        return record
    }
}








