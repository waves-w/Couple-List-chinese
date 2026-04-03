//
//  ScoreManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import CoreData
import MagicalRecord

// ✅ 全局分数更新通知名（供PointsView监听）
public let ScoreDidUpdateNotification = NSNotification.Name(rawValue: "ScoreDidUpdateNotification")

class ScoreManager: NSObject {
    // ✅ 单例（全局唯一）
    static let shared = ScoreManager()
    private override init() {
        super.init()
        // ✅ 延迟启动监听器，等待 coupleId 设置完成
        // 不在 init 中直接启动，避免 coupleId 为空时创建无效监听器
        
        // ✅ 监听断开链接通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleDidUnlink),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
    }
    
    @objc private func handleCoupleDidUnlink() {
        print("🔔 ScoreManager: 收到断开链接通知，停止监听器并清除缓存")
        
        // 1. 停止所有 Firebase 监听器
        removeScoreListeners()
        
        // 2. 清除分数缓存
        userScoreCache.removeAll()
        scoreRecordsCache.removeAll()
        scoreRecordsCacheTime = nil
        
        print("✅ ScoreManager: 断开链接处理完成，监听器和缓存已清除")
    }
    
    // Firebase核心路径（独立归档，与任务解耦）
    private let db = Firestore.firestore()
    private var scoreRecordPath: String { "/couples/\(coupleId)/score_records" } // 分数明细归档
    private var totalScorePath: String { "/couples/\(coupleId)/total_scores" }   // 总分数归档
    
    // ✅ 分数内存缓存【核心】解决页面刷新延迟、不更新问题
    private var userScoreCache: [String: Int] = [:]
    
    // ✅ 分数记录缓存（避免重复网络请求）
    private var scoreRecordsCache: [ScoreRecordModel] = []
    private var scoreRecordsCacheTime: Date?
    private let scoreRecordsCacheTimeout: TimeInterval = 1800 // 30分钟缓存有效期（大幅减少网络请求，提升性能）
    
    // ✅ 本地持久化存储 Key（UserDefaults）
    private let localScoreRecordsKey = "LocalScoreRecords"
    
    // ✅ Firebase实时监听器（监听双方分数变化）
    private var scoreListeners: [ListenerRegistration] = []
    private var isListenerSetup = false // ✅ 防止重复创建监听器
    private var scoreNotificationWorkItem: DispatchWorkItem? // ✅ 通知防抖任务
    private var lastNotificationTime: Date = Date.distantPast // ✅ 通知防抖
    private let notificationDebounceInterval: TimeInterval = 0.5 // ✅ 0.5秒防抖
    
    // 关联属性
    private var coupleId: String { CoupleStatusManager.getPartnerId() ?? "" }
    private var currentUserId: String { CoupleStatusManager.getUserUniqueUUID() }
    
    // MARK: ✅ 核心方法 - 获取情侣双方分数（完全从CoreData的ListModel计算）
    func getCoupleScores(completion: @escaping (Int, Int) -> Void) {
        let myId = currentUserId
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        var partnerId = partnerUser?.id ?? ""
        
        if partnerId.isEmpty {
            if let coupleId = CoupleStatusManager.getPartnerId() {
                let db = Firestore.firestore()
                // ✅ 优化：Firebase查询已经在后台线程执行，但确保回调也在后台线程处理
                db.collection("couples").document(coupleId).getDocument { snapshot, error in
                    guard let snapshot = snapshot, snapshot.exists, error == nil,
                          let data = snapshot.data() else {
                        self.getUserTotalScore(myId) { myScore in
                            DispatchQueue.main.async {
                                completion(myScore, 0)
                            }
                        }
                        return
                    }
                    
                    let initiatorUUID = data["initiatorUserId"] as? String ?? ""
                    let partnerUserId = data["partnerUserId"] as? String ?? ""
                    let actualPartnerUUID = (myId == initiatorUUID) ? partnerUserId : initiatorUUID
                    
                    let finalPartnerId = (!actualPartnerUUID.isEmpty && actualPartnerUUID != myId) ? actualPartnerUUID : ""
                    
                    self.executeGetCoupleScores(myId: myId, partnerId: finalPartnerId, completion: completion)
                }
                return
            }
        }
        
        // ✅ 直接执行分数获取
        executeGetCoupleScores(myId: myId, partnerId: partnerId, completion: completion)
    }
    
    // ✅ 抽离分数获取逻辑，避免重复代码
    private func executeGetCoupleScores(myId: String, partnerId: String, completion: @escaping (Int, Int) -> Void) {
        guard !partnerId.isEmpty else {
            getUserTotalScore(myId) { myScore in
                DispatchQueue.main.async { completion(myScore, 0) }
            }
            return
        }
        let group = DispatchGroup()
        var myScore: Int = 0
        var partnerScore: Int = 0
        group.enter()
        getUserTotalScore(myId) { score in
            myScore = score
            group.leave()
        }
        group.enter()
        getUserTotalScore(partnerId) { score in
            partnerScore = score
            group.leave()
        }
        group.notify(queue: .main) {
            completion(myScore, partnerScore)
        }
    }
    
    // MARK: ✅ 核心方法1 - 任务完成分数奖惩计算（核心逻辑+通知发送）
    /// - 按时完成 → 加指定分 | 逾期完成 → 加0分 | 逾期未完成 → 扣分（由 minusScoreForExpiredTask 触发）
    /// - ✅ 修复：0=给对方任务→加减伴侣分 |1=给自己任务→加减自己分 |2=双方任务→加减【自己+伴侣】分数
    func calculateTaskScore(_ model: ListModel, finishTime: Date = Date()) {
        guard !coupleId.isEmpty, let taskId = model.id, !taskId.isEmpty else {
            print("❌ 分数计算失败：情侣ID/任务ID为空")
            return
        }
        let taskSetTime = model.taskDate ?? Date() // 任务截止时间
        let targetScore = Int(model.points)        // 任务设置的分数
        let assignIndex = Int(model.assignIndex)   // 任务分配对象
        
        guard targetScore > 0 else {
            print("ℹ️ 任务[\(taskId)]未设置分数，跳过奖惩")
            return
        }
        
        // ✅ 修复3：检查任务是否已经完成过（防止重复加分/重复加0分）
        if let existingRecord = scoreRecordsCache.first(where: { 
            $0.taskId == taskId && $0.score >= 0  // 已有加分或加0分记录即视为已完成过
        }) {
            print("⚠️ 任务[\(taskId)]已经完成过，跳过重复（完成时间：\(existingRecord.taskFinishTime)，分数：\(existingRecord.score)）")
            return
        }
        
        // ✅ 核心规则：按时完成=加分，逾期完成=加0分（不扣分、写一条0分记录），逾期未完成=不扣分（见 AppDelegate 不再触发扣分）
        let isOnTime = finishTime <= taskSetTime
        let finalScore = isOnTime ? targetScore : 0 // ✅ 按时完成加分，逾期完成加0分
        
        if finalScore == 0 {
            print("ℹ️ 任务[\(taskId)]逾期完成，加0分（不扣分、仅写记录）")
        } else {
            print("✅ 任务[\(taskId)]分数计算：按时完成+\(finalScore)分")
        }
        
        // ✅ 核心匹配：确定「加减分的目标用户」（严格对应任务分配，不管谁点的完成）
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUserId = partnerUser?.id ?? ""
        var targetUserIds: [String] = [] // 改为数组，支持多用户（双方任务）
        
        // ✅ 调试日志：打印当前用户和伴侣用户信息
        print("🔍 分数计算调试信息：")
        print("  - 当前用户UUID: \(currentUserId)")
        print("  - 当前用户Model: \(currentUser?.id ?? "nil")")
        print("  - 伴侣用户UUID: \(partnerUserId)")
        print("  - 伴侣用户Model: \(partnerUser?.id ?? "nil")")
        print("  - 任务分配索引: \(assignIndex)")
        print("  - 任务ID: \(taskId)")
        
        switch assignIndex {
        case 0:
            // ✅ 修复：0-给对方的任务 → 仅给【伴侣】加减分（不管谁点的完成）
            guard !partnerUserId.isEmpty else {
                print("❌ 伴侣ID为空，跳过伴侣分数更新")
                // ✅ 兜底：如果getCoupleUsers找不到伴侣，尝试从Firebase couples文档获取
                if let coupleId = CoupleStatusManager.getPartnerId() {
                    db.collection("couples").document(coupleId).getDocument { [weak self] snapshot, error in
                        guard let self = self, let snapshot = snapshot, snapshot.exists, error == nil,
                              let data = snapshot.data() else { return }
                        let initiatorUUID = data["initiatorUserId"] as? String ?? ""
                        let partnerUserIdFromFirebase = data["partnerUserId"] as? String ?? ""
                        let actualPartnerUUID = (self.currentUserId == initiatorUUID) ? partnerUserIdFromFirebase : initiatorUUID
                        if !actualPartnerUUID.isEmpty && actualPartnerUUID != self.currentUserId {
                            print("✅ 从Firebase获取到伴侣UUID：\(actualPartnerUUID)，开始加分")
                            self.addScoreRecord(model, targetUserId: actualPartnerUUID, score: finalScore, isOnTime: isOnTime, finishTime: finishTime)
                            self.updateUserTotalScore(actualPartnerUUID, addScore: finalScore) {
                                // ✅ 注意：不在这里发送通知，因为 calculateTaskScore 的 group.notify 会统一发送通知，避免重复通知
                            }
                        }
                    }
                }
                return
            }
            targetUserIds.append(partnerUserId)
            print("✅ 任务分配给对方(assignIndex=0) → 仅更新伴侣分数[\(partnerUserId)]")
        case 1:
            // ✅ 修复：1-给自己的任务 → 仅给【自己】加减分（不管谁点的完成）
            targetUserIds.append(currentUserId)
            print("✅ 任务分配给自己(assignIndex=1) → 仅更新自己分数[\(currentUserId)]")
        case 2:
            // ✅2-双方任务 → 给【自己+伴侣】同时加减分（不管谁点的完成）
            guard !partnerUserId.isEmpty else {
                print("⚠️ 伴侣ID为空，双方任务仅更新自己分数")
                targetUserIds.append(currentUserId)
                break
            }
            targetUserIds.append(currentUserId)
            targetUserIds.append(partnerUserId)
            print("✅ 任务分配给双方(assignIndex=2) → 同时更新自己[\(currentUserId)]+伴侣[\(partnerUserId)]分数")
        default:
            print("❌ 无效的分配索引\(assignIndex)，跳过分数计算")
            return
        }
        
        guard !targetUserIds.isEmpty else {
            print("❌ 目标用户ID为空，跳过分数奖惩")
            return
        }
        
        // 执行多用户分数更新+归档+通知（批量处理）
        let group = DispatchGroup()
        
        targetUserIds.forEach { userId in
            guard !userId.isEmpty else { return } // ✅ 跳过空用户ID
            group.enter()
            self.addScoreRecord(model, targetUserId: userId, score: finalScore, isOnTime: isOnTime, finishTime: finishTime)
            self.updateUserTotalScore(userId, addScore: finalScore) {
                group.leave() // ✅ 确保 leave 总是被调用
            }
        }
        
        group.notify(queue: .main) {
            // ✅ 延迟发送通知，避免与监听器通知冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: ScoreDidUpdateNotification, object: nil)
            }
            print("✅ ✅ 全部用户分数更新完成，全局刷新通知已发送 ✅ ✅")
        }
    }
    
    // MARK: ✅ ✅ 核心新增 - 任务取消完成 分数撤回（双向逻辑）✅ ✅
    /// 取消完成时：原路返还分数（加了多少扣多少，扣了多少加多少）
    /// - Parameter finishTime: 任务完成时的时间（如果未提供，会从分数记录中查找）
    func withdrawTaskScore(_ model: ListModel, finishTime: Date? = nil) {
        guard !coupleId.isEmpty, let taskId = model.id, !taskId.isEmpty else { return }
        let taskSetTime = model.taskDate ?? Date()
        let targetScore = Int(model.points)
        let assignIndex = Int(model.assignIndex)
        guard targetScore > 0 else { return }
        
        // ✅ 修复2：如果未提供完成时间，从分数记录中查找（使用缓存优先，避免网络请求）
        var actualFinishTime = finishTime ?? Date()
        if finishTime == nil {
            // 先尝试从缓存中查找该任务的完成记录
            let completionRecord = scoreRecordsCache.first(where: { 
                $0.taskId == taskId && $0.score > 0 
            })
            
            if let record = completionRecord {
                actualFinishTime = record.taskFinishTime
                print("✅ 从缓存中找到任务[\(taskId)]完成时间：\(actualFinishTime)")
            } else {
                // 如果缓存中没有，使用任务截止时间（避免递归调用和网络请求）
                actualFinishTime = taskSetTime
                print("ℹ️ 缓存中未找到任务[\(taskId)]完成记录，使用任务截止时间：\(actualFinishTime)")
            }
        }
        
        // ✅ 取消完成时：删除该任务的「加分或加0分」记录，并按实际删除的正分总和撤回（逾期完成加0分则撤回0）
        print("✅ 任务[\(taskId)]取消完成 → 删除完成记录并撤回对应分数")
        
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUserId = partnerUser?.id ?? ""
        var targetUserIds: [String] = []
        
        switch assignIndex {
        case 0: // ✅ 修复：0=给对方的任务
            guard !partnerUserId.isEmpty else { return }
            targetUserIds.append(partnerUserId)
        case 1: // ✅ 修复：1=给自己的任务
            targetUserIds.append(currentUserId)
        case 2:
            targetUserIds.append(currentUserId)
            if !partnerUserId.isEmpty { targetUserIds.append(partnerUserId) }
        default: return
        }
        guard !targetUserIds.isEmpty else { return }
        
        let group = DispatchGroup()
        targetUserIds.forEach { userId in
            guard !userId.isEmpty else { return } // ✅ 跳过空用户ID
            group.enter()
            // ✅ 删除该任务该用户的完成记录（含加分 score>0 与加0分 score==0），按删除的正分总和撤回
            self.deleteCompletionRecordsForTask(taskId: taskId, targetUserId: userId) { [weak self] totalPositiveDeleted in
                guard let self = self else {
                    group.leave()
                    return
                }
                if totalPositiveDeleted > 0 {
                    print("✅ 已删除任务[\(taskId)]的完成记录，撤回\(totalPositiveDeleted)分")
                    self.updateUserTotalScore(userId, addScore: -totalPositiveDeleted) {
                        group.leave()
                    }
                } else {
                    print("ℹ️ 任务[\(taskId)]无正分记录可撤（可能为逾期完成加0分），仅删除记录")
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            NotificationCenter.default.post(name: ScoreDidUpdateNotification, object: nil)
            print("✅ ✅ 分数撤回完成，全局刷新通知已发送 ✅ ✅")
        }
    }
    
    // MARK: ✅ 核心拓展 - 任务过期自动减分（未完成逾期 → 更新已有加分记录为减分，不新建记录）
    func minusScoreForExpiredTask(_ model: ListModel) {
        guard !coupleId.isEmpty, let taskId = model.id, !taskId.isEmpty else { return }
        let targetScore = Int(model.points)
        let assignIndex = Int(model.assignIndex)
        guard targetScore > 0 else { return }
        
        // ✅ 核心修复：如果任务已经完成，不应该再扣分
        guard !model.isCompleted else {
            print("ℹ️ 任务[\(taskId)]已完成，跳过逾期扣分（已完成的任务不应该再扣分）")
            return
        }
        
        // ✅ 过期固定扣减分数（和逾期完成规则一致）
        let finalScore = -targetScore
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUserId = partnerUser?.id ?? ""
        var targetUserIds: [String] = []
        
        switch assignIndex {
        case 0: // ✅ 修复：0=给对方的任务
            guard !partnerUserId.isEmpty else { return }
            targetUserIds.append(partnerUserId)
        case 1: // ✅ 修复：1=给自己的任务
            targetUserIds.append(currentUserId)
        case 2:
            targetUserIds.append(currentUserId)
            if !partnerUserId.isEmpty { targetUserIds.append(partnerUserId) }
        default: return
        }
        guard !targetUserIds.isEmpty else { return }
        
        let group = DispatchGroup()
        targetUserIds.forEach { userId in
            group.enter()
            // ✅ 优先更新已有加分记录，如果没有则创建新记录
            self.updateExistingScoreRecord(taskId: taskId, targetUserId: userId, newScore: finalScore, isOnTime: false) { [weak self] updated in
                guard let self = self else {
                    group.leave()
                    return
                }
                if !updated {
                    // ✅ 如果更新失败（没找到记录），创建新记录作为兜底
                    self.addScoreRecord(model, targetUserId: userId, score: finalScore, isOnTime: false, finishTime: Date())
                }
                self.updateUserTotalScore(userId, addScore: finalScore) {
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            NotificationCenter.default.post(name: ScoreDidUpdateNotification, object: nil)
            print("✅ ✅ 任务[\(taskId)]过期，全部用户扣分完成 ✅ ✅")
        }
    }
    
    // MARK: ✅ 任务删除：彻底删除所有相关分数记录，并更新总分数
    func minusScoreForDeletedTask(_ model: ListModel) {
        guard !coupleId.isEmpty, let taskId = model.id, !taskId.isEmpty else { return }
        
        print("🗑️ 开始删除任务[\(taskId)]的所有分数记录")
        
        // ✅ 1. 查找并删除所有与该任务相关的分数记录
        db.collection(scoreRecordPath)
            .whereField("taskId", isEqualTo: taskId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ 查找任务[\(taskId)]的分数记录失败：\(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ 任务[\(taskId)]没有分数记录，无需删除")
                    NotificationCenter.default.post(name: ScoreDidUpdateNotification, object: nil)
                    return
                }
                
                // ✅ 2. 计算需要从总分数中减去的分数（只计算加分记录）
                var scoreDeductions: [String: Int] = [:] // userId -> 需要减去的分数
                
                for doc in documents {
                    let data = doc.data()
                    guard let targetUserId = data["targetUserId"] as? String,
                          let score = data["score"] as? Int else { continue }
                    
                    // ✅ 只计算加分记录（score > 0），减分记录不需要处理
                    if score > 0 {
                        let currentDeduction = scoreDeductions[targetUserId] ?? 0
                        scoreDeductions[targetUserId] = currentDeduction + score
                    }
                }
                
                // ✅ 3. 删除所有分数记录
                let deleteGroup = DispatchGroup()
                for doc in documents {
                    deleteGroup.enter()
                    doc.reference.delete { error in
                        if let error = error {
                            print("❌ 删除分数记录[\(doc.documentID)]失败：\(error.localizedDescription)")
                        } else {
                            print("✅ 已删除分数记录[\(doc.documentID)]")
                        }
                        deleteGroup.leave()
                    }
                }
                
                // ✅ 4. 更新总分数（减去之前加过的分数）
                deleteGroup.notify(queue: .main) {
                    let updateGroup = DispatchGroup()
                    for (userId, deduction) in scoreDeductions {
                        updateGroup.enter()
                        self.updateUserTotalScore(userId, addScore: -deduction) {
                            print("✅ 已从用户[\(userId)]总分数中减去\(deduction)分")
                            updateGroup.leave()
                        }
                    }
                    
                    updateGroup.notify(queue: .main) {
                        // ✅ 5. 清除缓存并发送通知（立即生效）
                        self.scoreRecordsCache.removeAll(where: { $0.taskId == taskId })
                        self.scoreRecordsCacheTime = Date() // 更新缓存时间
                        NotificationCenter.default.post(name: ScoreDidUpdateNotification, object: nil)
                        print("✅ ✅ 任务[\(taskId)]删除完成，已删除\(documents.count)条分数记录，缓存已更新 ✅ ✅")
                    }
                }
            }
    }
    
    // MARK: ✅ 核心方法2 - 新增分数变动明细（归档到Firebase）
    private func addScoreRecord(_ taskModel: ListModel, targetUserId: String, score: Int, isOnTime: Bool, finishTime: Date) {
        let record = ScoreRecordModel()
        record.coupleId = coupleId
        record.targetUserId = targetUserId
        record.taskId = taskModel.id ?? ""
        record.taskTitle = taskModel.titleLabel ?? "未命名任务"
        record.taskNotes = taskModel.notesLabel ?? ""
        record.taskSetTime = taskModel.taskDate ?? Date()
        record.taskFinishTime = finishTime
        record.score = score
        record.isOnTime = isOnTime
        record.createTime = Date()
        
        // ✅ 先更新本地缓存（立即生效，不等待网络）
        // ✅ 修复：同步更新缓存，确保立即生效（如果已在主线程则直接执行，否则异步执行）
        // ✅ 注意：不在这里发送通知，因为 calculateTaskScore 会在批量操作完成后统一发送通知，避免重复通知导致循环刷新
        if Thread.isMainThread {
            self.scoreRecordsCache.insert(record, at: 0) // 插入到最前面（最新的记录）
            self.scoreRecordsCacheTime = Date() // 更新缓存时间
            print("✅ 分数记录已添加到本地缓存（主线程同步）")
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scoreRecordsCache.insert(record, at: 0) // 插入到最前面（最新的记录）
                self.scoreRecordsCacheTime = Date() // 更新缓存时间
                print("✅ 分数记录已添加到本地缓存（异步）")
            }
        }
        
        // ✅ 异步上传到 Firebase（不阻塞）
        db.collection(scoreRecordPath).document(record.recordId).setData(record.toDict()) { error in
            if let error = error {
                print("❌ 分数明细归档失败：\(error)")
            } else {
                print("✅ 分数明细已同步到 Firebase")
            }
        }
    }
    
    // MARK: ✅ 任务编辑：更新该任务关联的所有 score 记录的 title / notes / 分数（Breakdown 显示与 Home 一致）
    func updateScoreRecordsTaskInfo(taskId: String, title: String, notes: String, points: Int) {
        guard !coupleId.isEmpty, !taskId.isEmpty else { return }
        
        db.collection(scoreRecordPath)
            .whereField("taskId", isEqualTo: taskId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ 查找任务[\(taskId)]的分数记录失败：\(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    return
                }
                
                let updateGroup = DispatchGroup()
                for doc in documents {
                    let data = doc.data()
                    let isOnTime = (data["isOnTime"] as? Bool) ?? true
                    let newScore = isOnTime ? points : -points
                    
                    updateGroup.enter()
                    doc.reference.updateData([
                        "taskTitle": title,
                        "taskNotes": notes,
                        "score": newScore
                    ]) { err in
                        if err != nil {
                            print("⚠️ 更新分数记录[\(doc.documentID)]失败")
                        }
                        updateGroup.leave()
                    }
                }
                
                updateGroup.notify(queue: .main) {
                    // ✅ 同步更新本地缓存中该 taskId 的记录的 title / notes / score
                    for i in self.scoreRecordsCache.indices where self.scoreRecordsCache[i].taskId == taskId {
                        self.scoreRecordsCache[i].taskTitle = title
                        self.scoreRecordsCache[i].taskNotes = notes
                        let onTime = self.scoreRecordsCache[i].isOnTime
                        self.scoreRecordsCache[i].score = onTime ? points : -points
                    }
                    self.scoreRecordsCacheTime = Date()
                    NotificationCenter.default.post(name: ScoreDidUpdateNotification, object: nil)
                }
            }
    }
    
    /// 删除该任务该用户的「完成记录」（加分 score>0 或加0分 score==0），返回被删记录中的正分总和（用于取消完成时按实际撤回）
    private func deleteCompletionRecordsForTask(taskId: String, targetUserId: String, completion: @escaping (Int) -> Void) {
        guard !coupleId.isEmpty, !taskId.isEmpty, !targetUserId.isEmpty else {
            completion(0)
            return
        }
        db.collection(scoreRecordPath)
            .whereField("taskId", isEqualTo: taskId)
            .whereField("targetUserId", isEqualTo: targetUserId)
            .whereField("score", isGreaterThanOrEqualTo: 0)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { completion(0); return }
                if let error = error {
                    print("❌ 查找完成记录失败：\(error.localizedDescription)")
                    completion(0)
                    return
                }
                let documents = snapshot?.documents ?? []
                var totalPositive: Int = 0
                for doc in documents {
                    if let score = doc.data()["score"] as? Int, score > 0 {
                        totalPositive += score
                    }
                }
                guard !documents.isEmpty else {
                    completion(0)
                    return
                }
                let deleteGroup = DispatchGroup()
                for doc in documents {
                    deleteGroup.enter()
                    doc.reference.delete { _ in deleteGroup.leave() }
                }
                deleteGroup.notify(queue: .main) {
                    self.scoreRecordsCache.removeAll(where: { $0.taskId == taskId && $0.targetUserId == targetUserId && $0.score >= 0 })
                    self.scoreRecordsCacheTime = Date()
                    completion(totalPositive)
                }
            }
    }
    
    // ✅ 新增：删除特定任务的加分记录（用于逾期扣分等场景，仅 score > 0）
    private func deleteScoreRecordsForTask(taskId: String, targetUserId: String, completion: @escaping (Bool) -> Void) {
        guard !coupleId.isEmpty, !taskId.isEmpty, !targetUserId.isEmpty else {
            print("⚠️ 删除分数记录失败：参数不完整")
            completion(false)
            return
        }
        
        // ✅ 查找该任务的加分记录（taskId + targetUserId + score > 0）
        db.collection(scoreRecordPath)
            .whereField("taskId", isEqualTo: taskId)
            .whereField("targetUserId", isEqualTo: targetUserId)
            .whereField("score", isGreaterThan: 0)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                if let error = error {
                    print("❌ 查找已有分数记录失败：\(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ 未找到任务[\(taskId)]的加分记录，无需删除")
                    completion(false)
                    return
                }
                
                // ✅ 删除所有找到的记录
                let deleteGroup = DispatchGroup()
                for doc in documents {
                    deleteGroup.enter()
                    doc.reference.delete { error in
                        if let error = error {
                            print("❌ 删除分数记录[\(doc.documentID)]失败：\(error.localizedDescription)")
                        } else {
                            print("✅ 已删除分数记录[\(doc.documentID)]")
                        }
                        deleteGroup.leave()
                    }
                }
                
                deleteGroup.notify(queue: .main) {
                    // ✅ 清除缓存（立即生效）
                    self.scoreRecordsCache.removeAll(where: { $0.taskId == taskId && $0.targetUserId == targetUserId && $0.score > 0 })
                    self.scoreRecordsCacheTime = Date() // 更新缓存时间
                    print("✅ 分数记录已从本地缓存删除，立即生效")
                    completion(true)
                }
            }
    }
    
    // ✅ 新增：更新已有分数记录（删除/过期时，将加分记录改为减分，不新建记录）
    private func updateExistingScoreRecord(taskId: String, targetUserId: String, newScore: Int, isOnTime: Bool, completion: @escaping (Bool) -> Void) {
        guard !coupleId.isEmpty, !taskId.isEmpty, !targetUserId.isEmpty else {
            print("⚠️ 更新分数记录失败：参数不完整")
            completion(false)
            return
        }
        
        // ✅ 查找该任务的加分记录（taskId + targetUserId + score > 0）
        db.collection(scoreRecordPath)
            .whereField("taskId", isEqualTo: taskId)
            .whereField("targetUserId", isEqualTo: targetUserId)
            .whereField("score", isGreaterThan: 0)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else {
                    completion(false)
                    return
                }
                
                if let error = error {
                    print("❌ 查找已有分数记录失败：\(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("ℹ️ 未找到任务[\(taskId)]的加分记录，需要创建新的减分记录")
                    completion(false)
                    return
                }
                
                // ✅ 找到加分记录，更新为减分
                let doc = documents[0]
                var data = doc.data()
                data["score"] = newScore
                data["isOnTime"] = isOnTime
                data["taskFinishTime"] = Timestamp(date: Date())
                
                doc.reference.updateData(data) { error in
                    if let error = error {
                        print("❌ 更新分数记录失败：\(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ 成功将任务[\(taskId)]的加分记录更新为减分记录")
                        completion(true)
                    }
                }
            }
    }
    
    // MARK: ✅ 核心方法3 - 分数更新（仅更新缓存，总分数从CoreData实时计算）
    private func updateUserTotalScore(_ userId: String, addScore: Int, completion: @escaping ()->Void) {
        // ✅ 分数完全从CoreData的ListModel计算，不需要更新Firebase的total_scores
        // ✅ 只需要清除缓存，让下次读取时重新从CoreData计算
        DispatchQueue.main.async { [weak self] in
            // ✅ 清除缓存，强制下次从CoreData重新计算
            self?.userScoreCache.removeValue(forKey: userId)
            completion()
        }
    }
    
    // MARK: ✅ 核心方法4 - 从CoreData获取分数（根据assignIndex区分用户）
    func getUserTotalScore(_ userId: String, completion: @escaping (Int) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(0)
                return
            }
            guard let allTasks = ListModel.mr_findAll() as? [ListModel] else {
                completion(0)
                return
            }
            let currentUserId = self.currentUserId
            let (_, partnerUser) = UserManger.manager.getCoupleUsers()
            let partnerUserId = partnerUser?.id ?? ""
            let isCurrentUser = (userId == currentUserId)
            let isPartnerUser = (userId == partnerUserId)
            guard isCurrentUser || isPartnerUser else {
                completion(0)
                return
            }
            var taskData: [(id: String?, assignIndex: Int, points: Int, taskDate: Date, isCompleted: Bool, creatorUUID: String?)] = []
            for task in allTasks {
                let taskPoints = Int(task.points)
                guard taskPoints > 0 else { continue }
                let creatorUUID = task.id != nil ? DbManager.manager.getTaskCreatorUUID(taskId: task.id!) : nil
                taskData.append((
                    id: task.id,
                    assignIndex: Int(task.assignIndex),
                    points: taskPoints,
                    taskDate: task.taskDate ?? Date(),
                    isCompleted: task.isCompleted,
                    creatorUUID: creatorUUID
                ))
            }
            
            // ✅ 在后台线程计算分数（避免阻塞主线程）
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async { completion(0) }
                    return
                }
                
                var totalScore = 0
                let currentDate = Date()
                var processedTasks = 0
                
                // ✅ 遍历任务数据，计算分数（不再访问CoreData对象）
                for task in taskData {
                    let assignIndex = task.assignIndex
                    let taskPoints = task.points
                    let taskDate = task.taskDate
                    let isCompleted = task.isCompleted
                    let isOverdue = !isCompleted && currentDate > taskDate
                    let creatorUUID = task.creatorUUID ?? currentUserId // 如果没有创建者信息，假设是当前用户创建的
                    
                    // ✅ 修复：根据 assignIndex 和创建者UUID严格区分用户（核心逻辑）
                    // assignIndex 是相对于创建者的，不是相对于当前查看者的
                    var shouldCountForThisUser = false
                    
                    // ✅ 判断创建者是当前用户还是伴侣
                    let isCreatedByCurrentUser = (creatorUUID == currentUserId)
                    let isCreatedByPartner = (creatorUUID == partnerUserId && !partnerUserId.isEmpty)
                    
                    switch assignIndex {
                    case 0:
                        if isCreatedByCurrentUser {
                            shouldCountForThisUser = isPartnerUser
                        } else if isCreatedByPartner {
                            shouldCountForThisUser = isCurrentUser
                        }
                    case 1:
                        if isCreatedByCurrentUser {
                            shouldCountForThisUser = isCurrentUser
                        } else if isCreatedByPartner {
                            shouldCountForThisUser = isPartnerUser
                        }
                    case 2:
                        shouldCountForThisUser = true
                    default:
                        continue
                    }
                    guard shouldCountForThisUser else { continue }
                    processedTasks += 1
                    if isCompleted {
                        totalScore += taskPoints
                    } else if isOverdue {
                        totalScore -= taskPoints
                    }
                }
                
                // ✅ 返回结果（主线程），在主线程更新缓存
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        completion(totalScore)
                        return
                    }
                    // ✅ 在主线程安全更新缓存
                    self.userScoreCache[userId] = totalScore
                    completion(totalScore)
                }
            }
        }
    }
    
    // MARK: ✅ 新增 - Firebase实时监听双方分数变化（核心功能）
    private func setupFirebaseScoreListener() {
        guard !coupleId.isEmpty else {
            print("❌ 分数监听启动失败：缺少Couple ID")
            isListenerSetup = false
            return
        }
        
        // ✅ 防止重复创建监听器
        if isListenerSetup && !scoreListeners.isEmpty {
            print("⚠️ 分数监听器已存在，跳过重复创建")
            return
        }
        
        // 移除旧监听器（确保清理）
        removeScoreListeners()
        
        let myId = currentUserId
        let partnerId = UserManger.manager.getCoupleUsers().1?.id ?? ""
        
        guard !myId.isEmpty else {
            print("❌ 分数监听启动失败：当前用户ID为空")
            isListenerSetup = false
            return
        }
        
        // ✅ 监听自己的分数变化
        let myScoreListener = db.collection(totalScorePath).document(myId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ 自己分数监听异常：\(error.localizedDescription)")
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else { return }
                
                let latestScore = UserTotalScoreModel.modelFromDict(snapshot.data()!).totalScore
                let oldCache = self.userScoreCache[myId]
                self.userScoreCache[myId] = latestScore
                
                // ✅ 分数变化时发送通知，更新UI（添加防抖）
                if oldCache != latestScore {
                    print("✅ 自己分数变化：\(oldCache ?? 0) → \(latestScore)")
                    // ✅ 防抖机制：避免频繁发送通知
                    self.postScoreUpdateNotificationWithDebounce()
                }
            }
        scoreListeners.append(myScoreListener)
        
        // ✅ 监听伴侣的分数变化
        guard !partnerId.isEmpty else {
            print("ℹ️ 伴侣ID为空，跳过伴侣分数监听")
            return
        }
        
        let partnerScoreListener = db.collection(totalScorePath).document(partnerId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("❌ 伴侣分数监听异常：\(error.localizedDescription)")
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else { return }
                
                let latestScore = UserTotalScoreModel.modelFromDict(snapshot.data()!).totalScore
                let oldCache = self.userScoreCache[partnerId]
                self.userScoreCache[partnerId] = latestScore
                
                // ✅ 分数变化时发送通知，更新UI（添加防抖）
                if oldCache != latestScore {
                    print("✅ 伴侣分数变化：\(oldCache ?? 0) → \(latestScore)")
                    // ✅ 防抖机制：避免频繁发送通知
                    self.postScoreUpdateNotificationWithDebounce()
                }
            }
        scoreListeners.append(partnerScoreListener)
        
        isListenerSetup = true
        print("✅ Firebase分数实时监听已启动（自己+伴侣），监听器数量：\(scoreListeners.count)")
    }
    
    // ✅ 防抖机制：避免频繁发送通知
    private func postScoreUpdateNotificationWithDebounce() {
        // ✅ 取消之前的通知任务
        scoreNotificationWorkItem?.cancel()
        
        let now = Date()
        let timeSinceLastNotification = now.timeIntervalSince(lastNotificationTime)
        
        // ✅ 如果距离上次通知时间小于防抖间隔，延迟发送（但不超过1秒）
        let delay: TimeInterval = timeSinceLastNotification < notificationDebounceInterval ? 
            min(notificationDebounceInterval - timeSinceLastNotification, 1.0) : 0
        
        scoreNotificationWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lastNotificationTime = Date()
            NotificationCenter.default.post(name: ScoreDidUpdateNotification, object: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: scoreNotificationWorkItem!)
    }
    
    // ✅ 公共方法：重新设置监听器（当伴侣ID变化时调用）
    func refreshScoreListener() {
        isListenerSetup = false
        removeScoreListeners()
        setupFirebaseScoreListener()
    }
    
    // ✅ 移除所有分数监听器
    private func removeScoreListeners() {
        let count = scoreListeners.count
        scoreListeners.forEach { listener in
            listener.remove()
        }
        scoreListeners.removeAll()
        isListenerSetup = false
        if count > 0 {
            print("✅ 已移除所有分数监听器（共\(count)个）")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removeScoreListeners()
        // ✅ 取消待执行的通知任务
        scoreNotificationWorkItem?.cancel()
        print("✅ ScoreManager 已销毁，监听移除成功")
    }
    
    /// 失效分数记录缓存（当另一台设备修改任务/assign 时调用，确保从 Firebase 拉取最新数据）
    func invalidateScoreRecordsCache() {
        scoreRecordsCache.removeAll()
        scoreRecordsCacheTime = nil
    }
    
    // MARK: ✅ 对外提供 - 获取所有分数变动明细（带缓存优化）
    func getAllScoreRecords(targetUserId: String? = nil, completion: @escaping ([ScoreRecordModel]) -> Void) {
        guard !coupleId.isEmpty else { completion([]); return }
        
        // ✅ 如果有缓存且未过期，直接返回缓存
        if let cacheTime = scoreRecordsCacheTime,
           Date().timeIntervalSince(cacheTime) < scoreRecordsCacheTimeout,
           !scoreRecordsCache.isEmpty {
            var filteredRecords = scoreRecordsCache
            if let userId = targetUserId, !userId.isEmpty {
                filteredRecords = filteredRecords.filter { $0.targetUserId == userId }
            }
            DispatchQueue.main.async {
                completion(filteredRecords)
            }
            // 后台更新缓存（不阻塞返回）
            refreshScoreRecordsCache(targetUserId: targetUserId)
            return
        }
        
        // ✅ 从网络获取并更新缓存
        refreshScoreRecordsCache(targetUserId: targetUserId, completion: completion)
    }
    
    // ✅ 刷新分数记录缓存
    private func refreshScoreRecordsCache(targetUserId: String? = nil, completion: (([ScoreRecordModel]) -> Void)? = nil) {
        var query = db.collection(scoreRecordPath).order(by: "createTime", descending: true)
        if let userId = targetUserId, !userId.isEmpty {
            query = query.whereField("targetUserId", isEqualTo: userId)
        }
        query.getDocuments { [weak self] snapshot, error in
            // ✅ 确保即使self为nil，completion也会被调用（避免崩溃）
            let records = snapshot?.documents.map { ScoreRecordModel.modelFromDict($0.data()) } ?? []
            
            // ✅ 更新缓存（如果self存在）
            if let self = self {
                self.scoreRecordsCache = records
                self.scoreRecordsCacheTime = Date()
            }
            
            // ✅ 如果有 completion，确保调用它（即使self为nil）
            if let completion = completion {
                DispatchQueue.main.async {
                    completion(records)
                }
            }
            // ✅ 注意：后台刷新缓存时不应该发送通知，因为这只是数据同步，不是分数变化
            // ✅ 只有真正的分数变化（完成任务、取消完成等）才应该发送通知
        }
    }
}
