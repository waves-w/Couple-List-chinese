//
//  DbManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import MagicalRecord
import ReactiveCocoa
import ReactiveSwift
import CoreData
import CocoaLumberjack

class DbManager: NSObject {
    
    static let manager = DbManager()
    var models = [ListModel]()
    let updatePipe = Signal<Int, Never>.pipe()
    static let dataDidUpdateNotification = Notification.Name("DataDidUpdateNotification")
    /// 通知 userInfo 里可选的任务 id，用于只刷新该行（重新判断预期等）
    static let dataDidUpdateItemIdKey = "itemId"
    var managedObjectContext: NSManagedObjectContext
    private var firebaseListener: ListenerRegistration?
    private var isLocalSyncing = false
    private var needRestartListener = false
    
    // ✅ ✅ 核心新增：缓存任务上一次的isCompleted状态（对比变更）✅ ✅
    private var taskLastCompletedStatus: [String: Bool] = [:]
    
    // ✅ ✅ 核心新增：缓存任务的创建者UUID（用于正确显示头像和计算分数）✅ ✅
    private var taskCreatorMap: [String: String] = [:]
    /// 串行队列：taskCreatorMap 在 Firestore 回调（后台）写入、在 UI 线程读取，必须串行访问避免崩溃
    private let taskCreatorMapQueue = DispatchQueue(label: "com.cuple.db.taskCreatorMap")
    
    // ✅ 记录正在同步的任务 ID，避免监听器重复处理
    private var syncingTaskIds = Set<String>()
    // ✅ 记录正在删除的任务 ID，避免监听器重复处理
    private var deletingTaskIds = Set<String>()
    
    // ✅ 防抖机制：避免频繁发送通知导致卡顿
    private var loadContentWorkItem: DispatchWorkItem?
    private var lastLoadContentTime: Date = Date.distantPast
    private let notificationDebounceInterval: TimeInterval = 0.5 // ✅ 防抖间隔：0.5秒
    
    // MARK: ✅ 日志辅助方法（同时输出到控制台和文件日志）
    private func logInfo(_ message: String) {
        // 使用 DDLog 记录到文件日志
        DDLog.log(asynchronous: true, level: .info, flag: .info, context: 0, file: #file, function: #function, line: #line, tag: nil, format: "%@", arguments: getVaList([message]))
        // 同时输出到控制台
        print(message)
    }
    
    private func logError(_ message: String) {
        // 使用 DDLog 记录到文件日志
        DDLog.log(asynchronous: true, level: .error, flag: .error, context: 0, file: #file, function: #function, line: #line, tag: nil, format: "%@", arguments: getVaList([message]))
        // 同时输出到控制台
        print(message)
    }
    
    private func logDebug(_ message: String) {
        // 使用 DDLog 记录到文件日志
        DDLog.log(asynchronous: true, level: .debug, flag: .debug, context: 0, file: #file, function: #function, line: #line, tag: nil, format: "%@", arguments: getVaList([message]))
        // 同时输出到控制台
        print(message)
    }
    
    override init() {
        self.managedObjectContext = NSManagedObjectContext.mr_default()
        super.init()
        
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Waves/ListModel.sqlite")
        logDebug("CoreData存储路径: \(storeURL)")
        
        guard let model = NSManagedObjectModel.mr_newManagedObjectModelNamed("ListModel.momd") else {
            fatalError("Failed to load Core Data model!")
        }
        NSManagedObjectModel.mr_setDefaultManagedObjectModel(model)
        MagicalRecord.setShouldAutoCreateManagedObjectModel(false)
        MagicalRecord.setupAutoMigratingCoreDataStack()
        
        setupCoreDataChangeListner()
        setupFirebaseRealTimeListener()
        loadContent()
        
        // ✅ ✅ 核心新增：启动时缓存所有任务的完成状态 ✅ ✅
        loadAllTaskCompletedStatus()
        
        // ✅ 监听断开链接通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleDidUnlink),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
        
        // ✅ 监听链接成功通知（用于重新链接后重启监听器）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleDidLink),
            name: NSNotification.Name("CoupleDidLinkNotification"),
            object: nil
        )
    }
    
    @objc private func handleCoupleDidUnlink() {
        logInfo("🔔 DbManager: 收到断开链接通知，停止监听器")
        removeFirebaseListener()
        needRestartListener = false
        logInfo("✅ DbManager: 断开链接处理完成")
    }
    
    @objc private func handleCoupleDidLink() {
        logInfo("🔔 DbManager: 收到链接成功通知，准备重启监听器")
        // ✅ 延迟一小段时间，确保 partnerId 已保存到 UserDefaults
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            // ✅ 再次检查 partnerId 是否存在
            if let coupleId = CoupleStatusManager.getPartnerId() {
                self.logInfo("✅ DbManager: partnerId 已设置 (\(coupleId))，重启监听器")
                self.setupFirebaseRealTimeListener()
                self.logInfo("✅ DbManager: 链接成功处理完成，监听器已重启")
            } else {
                self.logInfo("⚠️ DbManager: partnerId 未设置，延迟重启监听器")
                // ✅ 如果 partnerId 还未设置，再延迟一段时间后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if let coupleId = CoupleStatusManager.getPartnerId() {
                        self.logInfo("✅ DbManager: partnerId 已设置 (\(coupleId))，重启监听器（延迟重试）")
                        self.setupFirebaseRealTimeListener()
                    } else {
                        self.logInfo("ℹ️ DbManager: partnerId 未设置，可能已断开链接，跳过重启监听器")
                    }
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        removeFirebaseListener()
        // ✅ 取消待执行的通知任务
        loadContentWorkItem?.cancel()
    }
    
    // ✅ ✅ 核心新增：加载所有任务的isCompleted状态，存入缓存 ✅ ✅
    private func loadAllTaskCompletedStatus() {
        let allTasks = ListModel.mr_findAll() as? [ListModel] ?? []
        allTasks.forEach { model in
            if let taskId = model.id {
                taskLastCompletedStatus[taskId] = model.isCompleted
            }
        }
        logInfo("✅ 初始化任务完成状态缓存，共\(allTasks.count)条任务")
    }
    
    // ✅ ✅ 核心新增：获取任务的创建者UUID（线程安全读取）✅ ✅
    func getTaskCreatorUUID(taskId: String) -> String? {
        return taskCreatorMapQueue.sync { taskCreatorMap[taskId] }
    }
    
    private func setupFirebaseRealTimeListener() {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            // ✅ 修复：引导页阶段没有 coupleId 是正常的，静默跳过，不弹出错误
            logInfo("ℹ️ DbManager: 没有 coupleId，跳过启动监听器（引导页阶段或未链接伴侣）")
            return
        }
        
        removeFirebaseListener()
        let db = Firestore.firestore()
        let itemsRef = db.collection("couples").document(coupleId).collection("items")
        
        firebaseListener = itemsRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            guard let snapshot = querySnapshot, error == nil else {
                AlertManager.showSingleButtonAlert(message: "❌ Waves listener failed.：\(error?.localizedDescription ?? "Unknown error")", target: self)
                return
            }
            
            // ✅ 优化：检查是否有需要处理的远程更新
            // 如果所有变更都是本地同步的任务，可以跳过（避免循环同步）
            let hasRemoteUpdates = snapshot.documentChanges.contains { change in
                let documentID = change.document.documentID
                // 如果任务不在 syncingTaskIds 中，说明是远程更新
                return !self.syncingTaskIds.contains(documentID) && !self.deletingTaskIds.contains(documentID)
            }
            
            if !hasRemoteUpdates && !snapshot.documentChanges.isEmpty {
                self.logInfo("ℹ️ [DbManager] 所有变更都是本地同步的任务，跳过处理（避免循环）")
                return
            }
            
            // ✅ 标记为「正在进行 Firebase → Core Data 同步」
            self.isLocalSyncing = true
            let localSyncGroup = DispatchGroup()
            for documentChange in snapshot.documentChanges {
                localSyncGroup.enter()
                let documentID = documentChange.document.documentID
                let data = documentChange.document.data()
                
                switch documentChange.type {
                case .added, .modified:
                    // ✅ 如果这个任务正在同步中，跳过（避免重复处理）
                    if self.syncingTaskIds.contains(documentID) {
                        self.logInfo("ℹ️ [DbManager] 跳过正在同步的任务: \(documentID)")
                        localSyncGroup.leave()
                        continue
                    }
                    self.syncItem(documentID: documentID, data: data) {
                        // ✅ 同步后更新缓存状态
                        if let model = ListModel.mr_findFirst(byAttribute: "id", withValue: documentID) {
                            self.taskLastCompletedStatus[documentID] = model.isCompleted
                        }
                        localSyncGroup.leave()
                    }
                case .removed:
                    // ✅ 如果这个任务正在删除中，跳过（避免重复处理）
                    if self.deletingTaskIds.contains(documentID) {
                        self.logInfo("ℹ️ [DbManager] 跳过正在删除的任务: \(documentID)")
                        localSyncGroup.leave()
                        continue
                    }
                    self.deleteItem(documentID: documentID) {
                        self.taskLastCompletedStatus.removeValue(forKey: documentID)
                        localSyncGroup.leave()
                    }
                }
            }
            
            localSyncGroup.notify(queue: .main) {
                self.isLocalSyncing = false
                self.loadContent()
            }
        }
        logInfo("✅ Firebase 实时监听已启动")
    }
    
    private func removeFirebaseListener() {
        firebaseListener?.remove()
        firebaseListener = nil
    }
    
    private func restartFirebaseListener() {
        if needRestartListener {
            setupFirebaseRealTimeListener()
            needRestartListener = false
        }
    }
    
    private func setupCoreDataChangeListner() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleContextDidSave(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: NSManagedObjectContext.mr_default())
    }
    
    @objc private func handleContextDidSave(_ notification: Notification) {
        guard !isLocalSyncing, let userInfo = notification.userInfo else { return }
        
        // ✅ 优化方案1：不移除和重启监听器，而是使用标志位暂停监听
        // 设置标志位，让监听器回调跳过处理（避免循环同步）
        isLocalSyncing = true
        
        let dispatchGroup = DispatchGroup()
        var syncedTaskIds: [String] = [] // ✅ 记录本次同步的 ID
        
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, !insertedObjects.isEmpty {
            for obj in insertedObjects {
                if let model = obj as? ListModel, let taskId = model.id {
                    syncedTaskIds.append(taskId)
                    dispatchGroup.enter()
                    syncModelToFirebase(model: model) { dispatchGroup.leave() }
                    // 初始化新任务状态缓存
                    taskLastCompletedStatus[taskId] = model.isCompleted
                }
            }
        }
        
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            for obj in updatedObjects {
                if let model = obj as? ListModel, let taskId = model.id {
                    syncedTaskIds.append(taskId)
                    dispatchGroup.enter()
                    syncModelToFirebase(model: model) { dispatchGroup.leave() }
                    
                    // ✅ ✅ 核心新增：对比isCompleted新旧状态，触发算分/撤回 ✅ ✅
                    let oldStatus = taskLastCompletedStatus[taskId] ?? false
                    let newStatus = model.isCompleted
                    if oldStatus != newStatus {
                        logInfo("✅ 检测到任务[\(taskId)]完成状态变更：\(oldStatus) → \(newStatus)")
                        if newStatus {
                            // ✅ 勾选完成 → 计算分数
                            ScoreManager.shared.calculateTaskScore(model)
                        } else {
                            // ✅ 取消完成 → 撤回分数
                            ScoreManager.shared.withdrawTaskScore(model)
                        }
                        // 更新缓存状态
                        taskLastCompletedStatus[taskId] = newStatus
                    }
                }
            }
        }
        
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletedObjects.isEmpty {
            for obj in deletedObjects {
                if let model = obj as? ListModel {
                    // ✅ 检测到 Core Data 删除，直接扣分
                    if model.points > 0 {
                        ScoreManager.shared.minusScoreForDeletedTask(model)
                    }
                    
                    dispatchGroup.enter()
                    deleteModelFromFirebase(model: model) { dispatchGroup.leave() }
                    // 删除缓存状态
                    if let taskId = model.id {
                        taskLastCompletedStatus.removeValue(forKey: taskId)
                    }
                }
            }
        }
        
        // ✅ 优化方案1：所有推送完成后，延迟重置标志位（不重启监听器）
        dispatchGroup.notify(queue: .global()) { [weak self] in
            guard let self = self else { return }
            
            // ✅ 延迟 2 秒后重置标志位和移除同步标记（确保监听器不会处理自己的数据）
            // 这样即使监听器收到自己的数据，也会被跳过（因为 isLocalSyncing 为 true）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                // 重置本地同步标志位，允许监听器处理远程更新
                self.isLocalSyncing = false
                // 移除同步标记
                for taskId in syncedTaskIds {
                    self.syncingTaskIds.remove(taskId)
                    self.logInfo("✅ [DbManager] 移除同步标记: \(taskId)")
                }
                self.logInfo("✅ [DbManager] 本地同步完成，已重置标志位，监听器恢复正常")
            }
        }
    }
    
    private func syncModelToFirebase(model: ListModel, completion: @escaping () -> Void) {
        // ✅ 如果没有coupleId（测试环境），直接完成，不同步到Firebase
        guard let itemID = model.id, let coupleId = CoupleStatusManager.getPartnerId(), !coupleId.isEmpty else {
            logInfo("ℹ️ syncModelToFirebase: 没有coupleId，跳过Firebase同步（测试模式）")
            completion()
            return
        }
        
        // ✅ 标记任务正在同步中，防止监听器重复处理
        syncingTaskIds.insert(itemID)
        
        // ✅ 修复：更新任务时不要用「当前用户」覆盖创建者。只使用已缓存的创建者；无缓存时才用当前用户（避免点击完成/未完成时把创建者改成点击者）
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let creatorUUID = taskCreatorMapQueue.sync { taskCreatorMap[itemID] } ?? currentUUID
        let creator8DigitId = CoupleStatusManager.shared.ownInvitationCode ?? ""
        let creatorName = UserManger.manager.getUserModelByUUID(creatorUUID)?.userName ?? "Name"
        
        let firestoreData: [String: Any] = [
            "title": model.titleLabel ?? "",
            "notes": model.notesLabel ?? "",
            "taskDate": Timestamp(date: model.taskDate ?? Date()),
            "timeString": model.timeString ?? "",
            "isAllDay": model.isAllDay,
            "points": model.points,
            "assignIndex": model.assignIndex,
            "creatorUUID": creatorUUID,
            "creator8DigitId": creator8DigitId,
            "creatorName": creatorName,
            "isReminderOn": model.isReminderOn,
            "isCompleted": model.isCompleted,
            "creationDate": Timestamp(date: model.creationDate ?? Date()),
            "serverTimestamp": FieldValue.serverTimestamp()
        ]
        
        DispatchQueue.global(qos: .utility).async {
            Firestore.firestore().collection("couples").document(coupleId).collection("items").document(itemID)
                .setData(firestoreData, merge: true) { [weak self] error in
                    if let error = error {
                        self?.logError("❌ 同步 Firebase 失败 (\(itemID)): \(error.localizedDescription)")
                        // ✅ 同步失败时立即移除标记，避免永久阻塞
                        self?.syncingTaskIds.remove(itemID)
                    } else {
                        self?.logInfo("✅ [DbManager] 同步到 Firebase 成功 (\(itemID))")
                        // ✅ 注意：标记会在 handleContextDidSave 的延迟重启时移除，这里不立即移除
                        // 这样可以确保监听器重启时不会处理自己的数据
                    }
                    completion()
                }
        }
    }
    
    private func deleteModelFromFirebase(model: ListModel, completion: @escaping () -> Void) {
        guard let itemID = model.id, let coupleId = CoupleStatusManager.getPartnerId() else {
            completion()
            return
        }
        
        // ✅ 标记任务正在删除中，防止监听器重复处理
        deletingTaskIds.insert(itemID)
        
        DispatchQueue.global(qos: .utility).async {
            Firestore.firestore().collection("couples").document(coupleId).collection("items").document(itemID)
                .delete { [weak self] error in
                    if let error = error {
                        self?.logError("❌ Firebase 删除失败 (\(itemID)): \(error.localizedDescription)")
                        // ✅ 删除失败时立即移除标记，避免永久阻塞
                        self?.deletingTaskIds.remove(itemID)
                    } else {
                        self?.logInfo("✅ [DbManager] Firebase 删除成功 (\(itemID))")
                        // ✅ 延迟移除标记（给监听器一些时间处理，避免重复删除）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            self?.deletingTaskIds.remove(itemID)
                        }
                    }
                    completion()
                }
        }
    }
    
    func loadContent() {
        models = ListModel.mr_findAllSorted(by: "creationDate", ascending: true) as? [ListModel] ?? []
        updatePipe.input.send(value: 1)
        
        loadContentWorkItem?.cancel()
        let now = Date()
        let timeSinceLastNotification = now.timeIntervalSince(lastLoadContentTime)
        let delay: TimeInterval = timeSinceLastNotification < notificationDebounceInterval ?
            min(notificationDebounceInterval - timeSinceLastNotification, 1.0) : 0
        
        loadContentWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lastLoadContentTime = Date()
            NotificationCenter.default.post(name: DbManager.dataDidUpdateNotification, object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: loadContentWorkItem!)
    }
    
    func loadCurrentMonthContent() -> [ListModel] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components)!
        let endDate = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", startOfMonth as NSDate, endDate as NSDate)
        return ListModel.mr_findAll(with: predicate) as? [ListModel] ?? []
    }
    
    func addModel(
        titleLabel: String,
        notesLabel: String,
        taskDate: Date,
        timeString: String,
        isAllDay: Bool,
        points: Int,
        assignIndex: Int,
        isReminderOn: Bool
    ) -> ListModel? {
        if let model = ListModel.mr_createEntity() {
            let taskId = UUID().uuidString
            model.id = taskId
            model.creationDate = Date()
            model.titleLabel = titleLabel
            model.notesLabel = notesLabel
            model.taskDate = taskDate
            model.timeString = timeString
            model.isAllDay = isAllDay
            model.points = Int32(points)
            model.assignIndex = Int32(assignIndex)
            model.isReminderOn = isReminderOn
            model.isCompleted = false
            
            // ✅ 保存创建者UUID到缓存（线程安全写入）
            let creatorUUID = CoupleStatusManager.getUserUniqueUUID()
            taskCreatorMapQueue.async { [weak self] in
                self?.taskCreatorMap[taskId] = creatorUUID
            }
            logInfo("✅ DbManager: 创建新任务[\(taskId)]，保存创建者UUID=\(creatorUUID)")
            
            NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
            saveContext()
            loadContent()
            self.createNotificationForTaskIfNeeded(model: model)
            // 初始化新任务缓存
            taskLastCompletedStatus[taskId] = false
            return model
        }
        return nil
    }
    
    private func createNotificationForTaskIfNeeded(model: ListModel) {
        guard model.isReminderOn else {
            logInfo("ℹ️ 任务[\(model.id ?? "nil")]提醒关闭，不创建通知")
            return
        }
        
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        var partnerUUID = partnerUser?.id ?? ""
        
        // ✅ 修复：如果 getCoupleUsers() 没找到伴侣，尝试从 Firebase couples 文档获取伴侣UUID（兜底方案）
        if partnerUUID.isEmpty {
            logInfo("⚠️ getCoupleUsers()未找到伴侣，尝试从Firebase couples文档获取伴侣UUID")
            if let coupleId = CoupleStatusManager.getPartnerId() {
                let db = Firestore.firestore()
                db.collection("couples").document(coupleId).getDocument { [weak self] snapshot, error in
                    guard let self = self else { return }
                    guard let snapshot = snapshot, snapshot.exists, error == nil,
                          let data = snapshot.data() else {
                        self.logError("❌ 从Firebase获取伴侣UUID失败：\(error?.localizedDescription ?? "文档不存在")")
                        return
                    }
                    
                    let currentUUID = CoupleStatusManager.getUserUniqueUUID()
                    let initiatorUUID = data["initiatorUserId"] as? String ?? ""
                    let partnerUserId = data["partnerUserId"] as? String ?? ""
                    
                    // 判断自己是发起方还是被邀请方，获取对方的UUID
                    let actualPartnerUUID = (currentUUID == initiatorUUID) ? partnerUserId : initiatorUUID
                    
                    if !actualPartnerUUID.isEmpty && actualPartnerUUID != currentUUID {
                        self.logInfo("✅ 从Firebase获取到伴侣UUID：\(actualPartnerUUID)，开始创建通知")
                        // 重新调用创建通知逻辑（使用获取到的partnerUUID）
                        self.createNotificationForTaskWithPartnerUUID(
                            model: model,
                            partnerUUID: actualPartnerUUID,
                            currentUUID: currentUUID
                        )
                    } else {
                        self.logError("❌ 无法确定伴侣UUID（currentUUID:\(currentUUID), initiator:\(initiatorUUID), partner:\(partnerUserId)）")
                    }
                }
                return // 异步获取，先返回
            }
        }
        
        let assignIndex = Int(model.assignIndex)
        let taskId = model.id ?? ""
        guard !taskId.isEmpty else { return }
        
        // 使用获取到的partnerUUID创建通知
        createNotificationForTaskWithPartnerUUID(model: model, partnerUUID: partnerUUID, currentUUID: currentUUID)
    }
    
    // ✅ 新增：抽离创建通知的核心逻辑（支持传入partnerUUID）
    // ✅ 修复：assignIndex=0=给对方同步通知，1=给自己本地通知，2=双方都通知
    private func createNotificationForTaskWithPartnerUUID(model: ListModel, partnerUUID: String, currentUUID: String) {
        let assignIndex = Int(model.assignIndex)
        let taskId = model.id ?? ""
        guard !taskId.isEmpty else { return }
        
        if assignIndex == 0 { // ✅ 修复：0=给对方手机添加通知（同步）
            guard !partnerUUID.isEmpty else {
                logError("❌ 分配索引0（给对方）→ 伴侣UUID为空，无法推送通知")
                return
            }
            logInfo("ℹ️ 分配索引0（给对方）→ 向伴侣[\(partnerUUID)]推送通知指令")
            syncNotificationTaskToPartner(taskId: taskId, partnerUUID: partnerUUID, model: model, isCreate: true)
        } else if assignIndex == 1 { // ✅ 修复：1=给自己本地创建通知
            logInfo("ℹ️ 分配索引1（给自己）→ 本机[\(currentUUID)]创建通知")
            LocalNotificationManager.shared.createTaskNotification(
                taskId: taskId, title: model.titleLabel ?? "待办任务", body: model.notesLabel ?? "",
                triggerDate: model.taskDate ?? Date(), isAllDay: model.isAllDay, isReminderOn: model.isReminderOn
            )
        } else if assignIndex == 2 { // 双方
            logInfo("ℹ️ 分配索引2（双方）→ 本机[\(currentUUID)]+伴侣[\(partnerUUID)]同时创建通知")
            LocalNotificationManager.shared.createTaskNotification(
                taskId: taskId, title: model.titleLabel ?? "待办任务", body: model.notesLabel ?? "",
                triggerDate: model.taskDate ?? Date(), isAllDay: model.isAllDay, isReminderOn: model.isReminderOn
            )
            guard !partnerUUID.isEmpty else {
                logError("❌ 分配索引2（双方）→ 伴侣UUID为空，仅本机创建通知")
                return
            }
            syncNotificationTaskToPartner(taskId: taskId, partnerUUID: partnerUUID, model: model, isCreate: true)
        }
    }
    
    // ✅ 新增：从Firebase同步任务时，只在本机创建通知（不向伴侣推送指令）
    private func createLocalNotificationForSyncedTask(model: ListModel, creatorUUID: String? = nil) {
        let assignIndex = Int(model.assignIndex)
        let taskId = model.id ?? ""
        guard !taskId.isEmpty, model.isReminderOn else { return }
        
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        
        // ✅ 修复：根据 assignIndex 和 creatorUUID 判断是否应该在本机创建通知
        // 从Firebase同步任务时，assignIndex 是从创建者的角度定义的：
        // - assignIndex == 0：创建者创建给对方的任务 → 如果创建者是对方，本机创建（这是分配给自己的任务）；如果创建者是自己，不创建（已通过通知指令推送）
        // - assignIndex == 1：创建者创建给自己的任务 → 如果创建者是自己，本机创建；如果创建者是对方，不创建（这是对方的任务）
        // - assignIndex == 2：创建者创建给双方的任务 → 无论创建者是谁，本机都应该创建
        
        // ✅ 判断创建者：如果提供了 creatorUUID，使用它；如果没有提供，假设是对方创建的（从Firebase同步通常是从对方同步过来的）
        let isCreatedByMe = (creatorUUID != nil && creatorUUID == currentUUID)
        
        var shouldCreateNotification = false
        
        switch assignIndex {
        case 0:
            // ✅ 修复：assignIndex=0：创建者创建给对方的任务
            // 如果创建者是对方，本机创建（这是分配给自己的任务）；如果创建者是自己，不创建（已通过通知指令推送）
            shouldCreateNotification = !isCreatedByMe
            if !isCreatedByMe {
                logInfo("✅ 从Firebase同步任务[\(taskId)]，assignIndex=0（对方创建给对方的任务），在本机[\(currentUUID)]创建通知")
            } else {
                logInfo("ℹ️ 从Firebase同步任务[\(taskId)]，assignIndex=0（自己创建给对方的任务），不创建通知（已通过通知指令推送）")
            }
        case 1:
            // ✅ 修复：assignIndex=1：创建者创建给自己的任务
            // 如果创建者是自己，本机创建；如果创建者是对方，不创建（这是对方的任务）
            shouldCreateNotification = isCreatedByMe
            if isCreatedByMe {
                logInfo("✅ 从Firebase同步任务[\(taskId)]，assignIndex=1（自己创建给自己的任务），在本机[\(currentUUID)]创建通知")
            } else {
                logInfo("ℹ️ 从Firebase同步任务[\(taskId)]，assignIndex=1（对方创建给自己的任务），不创建通知（这是对方的任务）")
            }
        case 2:
            // ✅ assignIndex=2：创建者创建给双方的任务
            // 无论创建者是谁，本机都应该创建通知
            shouldCreateNotification = true
            logInfo("✅ 从Firebase同步任务[\(taskId)]，assignIndex=2（双方的任务），在本机[\(currentUUID)]创建通知")
        default:
            shouldCreateNotification = false
            logInfo("⚠️ 从Firebase同步任务[\(taskId)]，无效的assignIndex=\(assignIndex)，不创建通知")
        }
        
        if shouldCreateNotification {
            LocalNotificationManager.shared.createTaskNotification(
                taskId: taskId, title: model.titleLabel ?? "待办任务", body: model.notesLabel ?? "",
                triggerDate: model.taskDate ?? Date(), isAllDay: model.isAllDay, isReminderOn: model.isReminderOn
            )
        }
    }
    
    private func syncNotificationTaskToPartner(taskId: String, partnerUUID: String, model: ListModel, isCreate: Bool) {
        guard let coupleId = CoupleStatusManager.getPartnerId(), !partnerUUID.isEmpty, !taskId.isEmpty else {
            logError("❌ 同步通知指令失败：参数缺失（CoupleID/伴侣UUID/任务ID）")
            return
        }
        
        let notifyData: [String: Any] = [
            "taskId": taskId,
            "title": model.titleLabel ?? "待办任务",
            "body": model.notesLabel ?? "",
            "triggerDate": Timestamp(date: model.taskDate ?? Date()), // ✅ Date → Timestamp 上传
            "isAllDay": model.isAllDay,
            "isReminderOn": model.isReminderOn,
            "isCreate": isCreate,
            "senderUUID": CoupleStatusManager.getUserUniqueUUID(),
            "serverTimestamp": FieldValue.serverTimestamp()
        ]
        
        Firestore.firestore().collection("couples")
            .document(coupleId)
            .collection("notification_tasks")
            .document(partnerUUID)
            .collection("tasks")
            .document(taskId)
            .setData(notifyData, merge: true) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logError("❌ 向伴侣[\(partnerUUID)]同步通知指令失败：\(error.localizedDescription)")
                } else {
                    let action = isCreate ? "创建" : "移除"
                    self.logInfo("✅ 向伴侣[\(partnerUUID)]同步\(action)通知指令成功（任务\(taskId)）")
                }
            }
    }
    
    // ✅ 新增：修复Bug5 - 伴侣端通知时间解析（Timestamp → Date）
    func parseNotificationTaskData(_ data: [String: Any]) -> (taskId: String?, triggerDate: Date?, isCreate: Bool?) {
        let taskId = data["taskId"] as? String
        let triggerDate = (data["triggerDate"] as? Timestamp)?.dateValue() // ✅ 关键解析逻辑
        let isCreate = data["isCreate"] as? Bool
        return (taskId, triggerDate, isCreate)
    }
    
    func removeNotificationForTask(model: ListModel) {
        let taskId = model.id ?? ""
        guard !taskId.isEmpty, model.isReminderOn else { return }
        
        LocalNotificationManager.shared.removeTaskNotification(taskId: taskId)
        logInfo("✅ 本机已移除任务[\(taskId)]通知")
        
        let assignIndex = Int(model.assignIndex)
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        
        // ✅ 修复：assignIndex=0/2 → 同步移除伴侣设备通知（0=给对方，2=双方）
        if (assignIndex == 0 || assignIndex == 2) && !partnerUUID.isEmpty {
            syncNotificationTaskToPartner(taskId: taskId, partnerUUID: partnerUUID, model: model, isCreate: false)
        }
    }
    
    func updateModel(_ model: ListModel){
        // ✅ 保存到CoreData（必须在主线程）
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        
        // ✅ 检查完成状态变化，触发分数计算（不依赖Firebase）
        if let taskId = model.id {
            let oldStatus = taskLastCompletedStatus[taskId] ?? false
            let newStatus = model.isCompleted
            if oldStatus != newStatus {
                logInfo("✅ DbManager: 检测到任务[\(taskId)]完成状态变更：\(oldStatus) → \(newStatus)")
                if newStatus {
                    // ✅ 勾选完成 → 计算分数（完全从CoreData计算，不依赖Firebase）
                    ScoreManager.shared.calculateTaskScore(model)
                } else {
                    // ✅ 取消完成 → 撤回分数（完全从CoreData计算，不依赖Firebase）
                    ScoreManager.shared.withdrawTaskScore(model)
                }
                taskLastCompletedStatus[taskId] = newStatus
            }
        }
        
        // ✅ 尝试同步到Firebase（如果没有coupleId会直接返回，不影响本地逻辑）
        syncModelToFirebase(model: model) { [weak self] in
            self?.loadContent()
            // ✅ loadContent() 内部已经发送了通知，这里不需要重复发送
        }
    }
    
    /// - Parameter completion: 可选；保存结束后在主线程回调，参数为是否找到并更新了该条记录（未找到时为 false）
    func updateItem(withId itemId: String, updatedData: [String: Any?], completion: ((Bool) -> Void)? = nil) {
        var didFindAndUpdate = false
        MagicalRecord.save({ (localContext) in
            guard let model = ListModel.mr_findFirst(byAttribute: "id", withValue: itemId, in: localContext) else { return }
            didFindAndUpdate = true
            for (key, value) in updatedData {
                switch key {
                case "titleLabel": model.titleLabel = value as? String
                case "notesLabel": model.notesLabel = value as? String
                case "taskDate": model.taskDate = value as? Date
                case "timeString": model.timeString = value as? String
                case "isAllDay": model.isAllDay = value as? Bool ?? false
                case "points": model.points = (value as? Int).map { Int32($0) } ?? 0
                case "assignIndex": model.assignIndex = (value as? Int).map { Int32($0) } ?? 0
                case "isReminderOn": model.isReminderOn = value as? Bool ?? false
                case "isCompleted": model.isCompleted = value as? Bool ?? false
                default: break
                }
            }
        }, completion: { (success, error) in
            if !didFindAndUpdate {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            if success {
                DispatchQueue.main.async {
                    // ✅ 从主 context 取出该条并 refresh，使 taskDate 等变更生效，列表/详情能按新时间重新判断预期（逾期）
                    let mainContext = NSManagedObjectContext.mr_default()
                    if let mainModel = ListModel.mr_findFirst(byAttribute: "id", withValue: itemId, in: mainContext) {
                        mainContext.refresh(mainModel, mergeChanges: true)
                    }
                    guard let updatedModel = ListModel.mr_findFirst(byAttribute: "id", withValue: itemId) as? ListModel else {
                        completion?(true)
                        return
                    }
                    self.syncModelToFirebase(model: updatedModel) { }
                    if let isReminderOn = updatedData["isReminderOn"] as? Bool {
                        isReminderOn ? self.createNotificationForTaskIfNeeded(model: updatedModel) : self.removeNotificationForTask(model: updatedModel)
                    }
                    if let taskId = updatedModel.id {
                        let oldStatus = self.taskLastCompletedStatus[taskId] ?? false
                        let newStatus = updatedModel.isCompleted
                        if oldStatus != newStatus {
                            if newStatus { ScoreManager.shared.calculateTaskScore(updatedModel) }
                            else { ScoreManager.shared.withdrawTaskScore(updatedModel) }
                            self.taskLastCompletedStatus[taskId] = newStatus
                        }
                        ScoreManager.shared.updateScoreRecordsTaskInfo(
                            taskId: taskId,
                            title: updatedModel.titleLabel ?? "",
                            notes: updatedModel.notesLabel ?? "",
                            points: Int(updatedModel.points)
                        )
                    }
                    NotificationCenter.default.post(name: DbManager.dataDidUpdateNotification, object: nil, userInfo: [DbManager.dataDidUpdateItemIdKey: itemId])
                    completion?(true)
                }
            } else {
                DispatchQueue.main.async { completion?(false) }
            }
        })
    }
    
    func deleteModel(_ listModel: ListModel) {
        // ✅ 先同步删除 Firebase 文档，另一台设备监听会收到删除并同步删本地
        deleteModelFromFirebase(model: listModel) { }
        
        // ✅ 检测到删除，直接扣分
        if listModel.points > 0 {
            ScoreManager.shared.minusScoreForDeletedTask(listModel)
        }
        
        self.removeNotificationForTask(model: listModel)
        listModel.mr_deleteEntity()
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        // 删除缓存
        if let taskId = listModel.id {
            taskLastCompletedStatus.removeValue(forKey: taskId)
        }
    }
    
    func saveContext() {
        do { try managedObjectContext.save() }
        catch { logError("Failed to save context: \(error)") }
    }
    
    func fetchListModels() -> [ListModel] {
        return ListModel.mr_findAllSorted(by: "creationDate", ascending: false) as? [ListModel] ?? []
    }
    
    // ✅ 测试方法：直接修改任务的完成状态（用于测试分数计算，不依赖Firebase）
    func toggleTaskCompletion(taskId: String, completion: @escaping (Bool) -> Void) {
        guard let model = ListModel.mr_findFirst(byAttribute: "id", withValue: taskId) else {
            logError("❌ 未找到任务ID为\(taskId)的任务")
            completion(false)
            return
        }
        
        // ✅ 切换完成状态
        let oldStatus = model.isCompleted
        let newStatus = !oldStatus
        model.isCompleted = newStatus
        
        // ✅ 保存到CoreData
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        
        // ✅ 触发分数计算（通过handleContextDidSave会自动触发，但这里也手动触发确保更新）
        if let taskId = model.id {
            let cachedStatus = taskLastCompletedStatus[taskId] ?? false
            if cachedStatus != newStatus {
                logInfo("✅ 测试：任务[\(taskId)]完成状态变更：\(cachedStatus) → \(newStatus)")
                if newStatus {
                    ScoreManager.shared.calculateTaskScore(model)
                } else {
                    ScoreManager.shared.withdrawTaskScore(model)
                }
                taskLastCompletedStatus[taskId] = newStatus
            }
        }
        
        // ✅ 发送通知，触发UI更新
        // ✅ 注意：不在这里发送 ScoreDidUpdateNotification，因为 calculateTaskScore 和 withdrawTaskScore 已经会发送通知，避免重复通知
        NotificationCenter.default.post(name: DbManager.dataDidUpdateNotification, object: nil)
        
        logInfo("✅ 测试：任务[\(taskId)]完成状态已切换为\(newStatus ? "已完成" : "未完成")")
        completion(true)
    }
    
    // ✅ 测试方法：直接设置任务的完成状态（用于测试分数计算）
    func setTaskCompletion(taskId: String, isCompleted: Bool, completion: @escaping (Bool) -> Void) {
        guard let model = ListModel.mr_findFirst(byAttribute: "id", withValue: taskId) else {
            logError("❌ 未找到任务ID为\(taskId)的任务")
            completion(false)
            return
        }
        
        // ✅ 设置完成状态
        let oldStatus = model.isCompleted
        model.isCompleted = isCompleted
        
        // ✅ 保存到CoreData
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        
        // ✅ 如果状态改变，触发分数计算
        if oldStatus != isCompleted, let taskId = model.id {
            logInfo("✅ 测试：任务[\(taskId)]完成状态变更：\(oldStatus) → \(isCompleted)")
            if isCompleted {
                ScoreManager.shared.calculateTaskScore(model)
            } else {
                ScoreManager.shared.withdrawTaskScore(model)
            }
            taskLastCompletedStatus[taskId] = isCompleted
        }
        
        // ✅ 发送通知，触发UI更新
        // ✅ 注意：不在这里发送 ScoreDidUpdateNotification，因为 calculateTaskScore 和 withdrawTaskScore 已经会发送通知，避免重复通知
        NotificationCenter.default.post(name: DbManager.dataDidUpdateNotification, object: nil)
        
        logInfo("✅ 测试：任务[\(taskId)]完成状态已设置为\(isCompleted ? "已完成" : "未完成")")
        completion(true)
    }
    
    // ✅ 重构方法，增加completion回调，配合同步组使用
    func syncItem(documentID: String, data: [String: Any], completion: @escaping () -> Void) {
        // ✅ 先检查是否是新建任务，以及旧的提醒状态
        let existingModel = ListModel.mr_findFirst(byAttribute: "id", withValue: documentID)
        let isNewModel = (existingModel == nil)
        let oldIsReminderOn = existingModel?.isReminderOn ?? false
        
        MagicalRecord.save({ [weak self] (localContext) in
            guard let self = self else { return }
            var targetModel: ListModel?
            if let existingModel = ListModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                targetModel = existingModel
            } else if let newModel = ListModel.mr_createEntity(in: localContext) {
                targetModel = newModel
                newModel.id = documentID
            }
            guard let model = targetModel else {
                completion()
                return
            }
            
            model.titleLabel = data["title"] as? String
            model.notesLabel = data["notes"] as? String
            if let taskDate = data["taskDate"] as? Timestamp { model.taskDate = taskDate.dateValue() }
            model.timeString = data["timeString"] as? String
            model.isAllDay = data["isAllDay"] as? Bool ?? false
            
            // ✅ 修复Bug4：安全解包NSNumber，杜绝强转崩溃
            model.points = (data["points"] as? NSNumber)?.int32Value ?? 0
            model.assignIndex = (data["assignIndex"] as? NSNumber)?.int32Value ?? 0
            
            model.isReminderOn = data["isReminderOn"] as? Bool ?? false
            model.isCompleted = data["isCompleted"] as? Bool ?? false
            
            // ✅ 保存创建者UUID到缓存（从Firebase同步时，线程安全写入：当前在 MagicalRecord 后台队列）
            if let creatorUUID = data["creatorUUID"] as? String {
                self.taskCreatorMapQueue.async {
                    self.taskCreatorMap[documentID] = creatorUUID
                }
                self.logInfo("✅ DbManager: 保存任务[\(documentID)]的创建者UUID=\(creatorUUID)")
            }
            
            if let timestamp = data["serverTimestamp"] as? Timestamp {
                model.creationDate = timestamp.dateValue()
            } else if model.creationDate == nil {
                model.creationDate = Date()
            }
        }, completion: { [weak self] (success, error) in
            guard let self = self else {
                completion()
                return
            }
            if success {
                // ✅ 同步成功后，检查是否需要创建或移除通知
                if let syncedModel = ListModel.mr_findFirst(byAttribute: "id", withValue: documentID) {
                    // ✅ 如果是新任务，或者提醒状态从关闭变为开启，需要创建通知
                    if (isNewModel || (!oldIsReminderOn && syncedModel.isReminderOn)) && syncedModel.isReminderOn {
                        // ✅ 获取创建者UUID（从Firebase数据中）
                        let creatorUUID = data["creatorUUID"] as? String
                        self.logInfo("✅ 从Firebase同步任务[\(documentID)]，需要创建通知（新任务:\(isNewModel), 旧提醒:\(oldIsReminderOn), 新提醒:\(syncedModel.isReminderOn), 创建者:\(creatorUUID ?? "未知")）")
                        // ✅ 修复：从Firebase同步时，根据创建者和assignIndex判断是否应该创建通知
                        self.createLocalNotificationForSyncedTask(model: syncedModel, creatorUUID: creatorUUID)
                    } else if oldIsReminderOn && !syncedModel.isReminderOn {
                        // ✅ 如果提醒状态从开启变为关闭，需要移除通知
                        self.logInfo("✅ 从Firebase同步任务[\(documentID)]，需要移除通知")
                        LocalNotificationManager.shared.removeTaskNotification(taskId: documentID)
                    }
                }
                // ✅ 批量 Firebase 同步时由 loadContent() 统一发一次通知，避免多次 post 加重主线程/第三方键盘卡顿
                if !self.isLocalSyncing {
                    NotificationCenter.default.post(name: DbManager.dataDidUpdateNotification, object: nil)
                }
            }
            completion()
        })
    }
    
    // ✅ 重构方法，增加completion回调，配合同步组使用
    func deleteItem(documentID: String, completion: @escaping () -> Void) {
        // ✅ 检测到删除，直接扣分
        if let modelToDelete = ListModel.mr_findFirst(byAttribute: "id", withValue: documentID) {
            if modelToDelete.points > 0 {
                ScoreManager.shared.minusScoreForDeletedTask(modelToDelete)
            }
        }
        
        // ✅ 删除时也清除创建者UUID缓存（线程安全写入）
        taskCreatorMapQueue.async { [weak self] in
            self?.taskCreatorMap.removeValue(forKey: documentID)
        }
        
        MagicalRecord.save({ (localContext) in
            if let modelToDelete = ListModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                modelToDelete.mr_deleteEntity(in: localContext)
            }
        }, completion: { (success, error) in
            if success {
                NotificationCenter.default.post(name: DbManager.dataDidUpdateNotification, object: nil)
            } else {
                self.logError("❌ Error deleting item in Core Data: \(error?.localizedDescription ?? "Unknown error")")
            }
            completion()
        })
    }
}
