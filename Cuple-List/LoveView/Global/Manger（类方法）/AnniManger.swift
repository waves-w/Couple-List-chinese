//
//  AnniManger.swift
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

class AnniManger: NSObject {
    
    static let manager = AnniManger()
    
    /// 本机引导页「在一起」纪念日当前使用的文档 id（改日期时若 id 变化则删掉旧的一条）。
    private static let bootRelationshipAnniUserDefaultsKey = "bootRelationshipAnniDocId"
    
    /// 同一日历日相同则 id 相同 → 伴侣 Firestore 上合并为一条；日期不同则 id 不同 → 各一条。
    private static func bootRelationshipAnniDocumentId(forDayStart dayStart: Date) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: dayStart)
        guard let y = c.year, let m = c.month, let d = c.day else {
            return "boot_rel_invalid"
        }
        return "boot_rel_\(y)_\(m)_\(d)"
    }
    private static let relationshipStartAnniTitle = "Date of relationship"
    private static let relationshipStartRepeatDate = "Every 1 Year"
    private static let relationshipStartWishImage = "💖"
    var models = [AnniModel]()
    let updatePipe = Signal<Int, Never>.pipe()
    static let dataDidUpdateNotification = Notification.Name("DataDidUpdateNotification")
    var managedObjectContext: NSManagedObjectContext
    var _dateFormatter: DateFormatter?
    var dateFormatter: DateFormatter {
        set {
            _dateFormatter = newValue
        }
        get {
            if _dateFormatter == nil {
                _dateFormatter = DateFormatter()
                _dateFormatter?.locale = Locale(identifier: "en_US_POSIX")
                _dateFormatter?.dateFormat = "yyyyMMddHHmmssSSS"
            }
            return _dateFormatter!
        }
    }
    private var firebaseListener: ListenerRegistration?
    // 🌟 新增：标记是否正在进行本地同步（避免循环同步）
    private var isLocalSyncing = false
    // 🌟 新增：标记是否需要重启监听（替代暂停/恢复）
    private var needRestartListener = false
    
    /// 本地写入期间 Firestore 监听器会故意丢弃快照；解锁后做一次全量拉取，避免链接后只显示本机纪念日。
    private var pendingPullAllAnnisFromFirestoreAfterLocalSync = false
    
    /// 仅从云端删除（取消共享）时登记：监听器收到 `.removed` 后**不要**删本机 Core Data，只让对方端删掉。
    private var anniDocumentIdsRetainLocalWhenFirestoreRemoves: Set<String> = []
    
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
        
        // 1. 监听 Core Data 变更 → 推送到 Firebase
        setupCoreDataChangeListner()
        // 2. 监听 Firebase 变更 → 同步到 Core Data
        setupFirebaseRealTimeListener()
        
        loadContent()
        
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
        logInfo("🔔 AnniManger: 收到断开链接通知，停止监听器")
        removeFirebaseListener()
        needRestartListener = false
        logInfo("✅ AnniManger: 断开链接处理完成")
    }
    
    @objc private func handleCoupleDidLink() {
        logInfo("🔔 AnniManger: 收到链接成功通知，准备重启监听器")
        // ✅ 延迟一小段时间，确保 partnerId 已保存到 UserDefaults
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            // ✅ 再次检查 partnerId 是否存在
            if let coupleId = CoupleStatusManager.getPartnerId() {
                self.logInfo("✅ AnniManger: partnerId 已设置 (\(coupleId))，重启监听器")
                self.ensureRelationshipStartAnniAfterCoupleLinked()
                self.setupFirebaseRealTimeListener()
                self.pushRelationshipStartAnniToFirebaseIfNeeded()
                self.logInfo("✅ AnniManger: 链接成功处理完成，监听器已重启")
            } else {
                self.logInfo("⚠️ AnniManger: partnerId 未设置，延迟重启监听器")
                // ✅ 如果 partnerId 还未设置，再延迟一段时间后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if let coupleId = CoupleStatusManager.getPartnerId() {
                        self.logInfo("✅ AnniManger: partnerId 已设置 (\(coupleId))，重启监听器（延迟重试）")
                        self.ensureRelationshipStartAnniAfterCoupleLinked()
                        self.setupFirebaseRealTimeListener()
                        self.pushRelationshipStartAnniToFirebaseIfNeeded()
                    } else {
                        self.logInfo("ℹ️ AnniManger: partnerId 未设置，可能已断开链接，跳过重启监听器")
                    }
                }
            }
        }
    }
    
    /// 链接成功后根据用户资料里的「在一起」日期创建/更新本地纪念日（引导阶段不再提前写入 Core Data）。
    private func ensureRelationshipStartAnniAfterCoupleLinked() {
        let uuid = UserManger.manager.currentUserUUID
        guard let user = UserManger.manager.getUserModelByUUID(uuid),
              let rel = user.relationshipStartDate else {
            logInfo("ℹ️ [AnniManger] 未设置在一起日期，跳过链接后创建纪念日")
            return
        }
        upsertRelationshipStartAnniFromBoot(targetDate: rel)
    }
    
    deinit {
        // 销毁时移除监听，避免内存泄漏
        NotificationCenter.default.removeObserver(self)
        removeFirebaseListener()
        // ✅ 取消待执行的通知任务
        loadContentWorkItem?.cancel()
    }
    
    /// 添加 Firebase 实时监听
    private func setupFirebaseRealTimeListener() {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            // ✅ 修复：引导页阶段没有 coupleId 是正常的，静默跳过，不弹出错误
            logInfo("ℹ️ AnniManger: 没有 coupleId，跳过启动监听器（引导页阶段或未链接伴侣）")
            return
        }
        
        removeFirebaseListener()
        
        let db = Firestore.firestore()
        let itemsRef = db.collection("annis")
            .document(coupleId)
            .collection("anni")
        
        // 注册实时监听
        firebaseListener = itemsRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            
            // ✅ 修复：改进错误处理，避免在主线程上显示弹窗导致崩溃
            if let error = error {
                let nsError = error as NSError
                self.logError("❌ [AnniManger] Firebase 监听器错误")
                self.logError("  - 错误代码: \(nsError.code)")
                self.logError("  - 错误描述: \(error.localizedDescription)")
                self.logError("  - 错误详情: \(nsError.userInfo)")
                
                // ✅ 检查是否是网络错误或权限错误
                if nsError.code == 14 { // UNAVAILABLE - 网络不可用
                    self.logInfo("⚠️ [AnniManger] 网络不可用，延迟3秒后重试...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.setupFirebaseRealTimeListener()
                    }
                } else if nsError.code == 7 { // PERMISSION_DENIED - 权限被拒绝
                    self.logInfo("⚠️ [AnniManger] 权限被拒绝，请检查 Firestore 安全规则")
                    // 权限错误不自动重试，需要用户修复配置
                } else {
                    // ✅ 其他错误，延迟2秒后重试
                    self.logInfo("⚠️ [AnniManger] 监听器错误，延迟2秒后重试...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.setupFirebaseRealTimeListener()
                    }
                }
                return
            }
            
            guard let snapshot = querySnapshot else {
                self.logInfo("⚠️ [AnniManger] snapshot 为空，跳过处理")
                return
            }
            
            self.logInfo("✅ [AnniManger] 收到 Firebase 数据更新")
            self.logInfo("  - 变更数量: \(snapshot.documentChanges.count)")
            self.logInfo("  - 总文档数: \(snapshot.documents.count)")
            
            // 本地正在往 Firebase 推数据时跳过监听器，避免循环；链接后常会漏掉伴侣已有数据 → 解锁后全量拉取
            if self.isLocalSyncing {
                self.pendingPullAllAnnisFromFirestoreAfterLocalSync = true
                self.logInfo("ℹ️ [AnniManger] 本地同步中，已标记待全量拉取 Firestore 纪念日")
                return
            }
            
            // Firestore 常见：缓存/首次回调 documentChanges 为空，但 documents 已有全集，不能只 loadContent
            if snapshot.documentChanges.isEmpty {
                if snapshot.documents.isEmpty {
                    self.loadContent()
                    return
                }
                self.logInfo("ℹ️ [AnniManger] 无增量变更，按 \(snapshot.documents.count) 条文档做全量合并")
                self.isLocalSyncing = true
                let mergeGroup = DispatchGroup()
                for doc in snapshot.documents {
                    mergeGroup.enter()
                    self.annisyncItem(documentID: doc.documentID, data: doc.data()) {
                        mergeGroup.leave()
                    }
                }
                mergeGroup.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }
                    self.logInfo("✅ [AnniManger] 快照文档已合并进 Core Data")
                    self.isLocalSyncing = false
                    self.loadContent()
                    self.schedulePullAllAnnisIfPending()
                }
                return
            }
            
            // ✅ 标记为「正在进行 Firebase → Core Data 同步」，避免循环
            self.isLocalSyncing = true
            let localSyncGroup = DispatchGroup()
            
            for documentChange in snapshot.documentChanges {
                let documentID = documentChange.document.documentID
                let data = documentChange.document.data()
                
                self.logDebug("  - 处理变更: \(documentChange.type) - ID: \(documentID)")
                
                localSyncGroup.enter()
                
                switch documentChange.type {
                case .added, .modified:
                    self.annisyncItem(documentID: documentID, data: data) {
                        self.logInfo("✅ [AnniManger] 同步完成: \(documentID)")
                        localSyncGroup.leave()
                    }
                case .removed:
                    if self.consumeAnniRetainLocalAfterFirestoreRemove(documentID: documentID) {
                        self.logInfo("ℹ️ [AnniManger] 取消共享：仅移除云端副本，保留本机该条纪念日 (\(documentID))")
                        localSyncGroup.leave()
                    } else {
                        self.annideleteItem(documentID: documentID) {
                            self.logInfo("✅ [AnniManger] 删除完成: \(documentID)")
                            localSyncGroup.leave()
                        }
                    }
                }
            }
            
            localSyncGroup.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.logInfo("✅ [AnniManger] 所有同步任务完成，重置标志并刷新数据")
                self.isLocalSyncing = false
                self.loadContent()
                self.schedulePullAllAnnisIfPending()
            }
        }
        
        logInfo("✅ Firebase 实时监听已启动")
    }
    
    /// 移除 Firebase 监听
    private func removeFirebaseListener() {
        firebaseListener?.remove()
        firebaseListener = nil
        logInfo("✅ Firebase 监听已移除")
    }
    
    /// 重启 Firebase 监听（替代 resume）
    private func restartFirebaseListener() {
        if needRestartListener {
            setupFirebaseRealTimeListener()
            needRestartListener = false
        }
    }
    
    // MARK: - 1. Core Data → Firebase 同步（修复暂停/恢复逻辑）
    private func setupCoreDataChangeListner() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContextDidSave(_:)),
            name: NSNotification.Name.NSManagedObjectContextDidSave,
            object: NSManagedObjectContext.mr_default()
        )
    }
    
    @objc private func handleContextDidSave(_ notification: Notification) {
        guard !isLocalSyncing else { return } // 本地同步时跳过（避免循环）
        guard let userInfo = notification.userInfo else { return }
        
        // ✅ 优化方案1：不移除和重启监听器，而是使用标志位暂停监听
        // 设置标志位，让监听器回调跳过处理（避免循环同步）
        isLocalSyncing = true
        
        // 处理新增/更新/删除
        let dispatchGroup = DispatchGroup()
        
        // 1. 新增对象
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, !insertedObjects.isEmpty {
            for obj in insertedObjects {
                if let model = obj as? AnniModel {
                    dispatchGroup.enter()
                    annisyncModelToFirebase(model: model) {
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        // 2. 更新对象（同步开启则 push；关闭则尝试从云端删除，避免「仅本地」仍留在对方 Firestore）
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            for obj in updatedObjects {
                if let model = obj as? AnniModel {
                    dispatchGroup.enter()
                    if model.isShared {
                        annisyncModelToFirebase(model: model) {
                            dispatchGroup.leave()
                        }
                    } else {
                        annideleteModelFromFirebase(model: model, isUnshareFromCloudOnly: true) {
                            dispatchGroup.leave()
                        }
                    }
                }
            }
        }
        
        // 3. 删除对象（仅曾同步到 Firestore 的需要从云端删除）
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletedObjects.isEmpty {
            for obj in deletedObjects {
                if let model = obj as? AnniModel, model.isShared {
                    dispatchGroup.enter()
                    annideleteModelFromFirebase(model: model) {
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        // ✅ 优化方案1：所有推送完成后，延迟重置标志位（不重启监听器）
        dispatchGroup.notify(queue: .global()) { [weak self] in
            guard let self = self else { return }
            
            // ✅ 延迟 2 秒后重置标志位（确保监听器不会处理自己的数据）
            // 这样即使监听器收到自己的数据，也会被跳过（因为 isLocalSyncing 为 true）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                // 重置本地同步标志位，允许监听器处理远程更新
                self.isLocalSyncing = false
                self.logInfo("✅ [AnniManger] 本地同步完成，已重置标志位，监听器恢复正常")
                self.schedulePullAllAnnisIfPending()
            }
        }
    }
    
    /// 若曾在 `isLocalSyncing` 期间漏掉监听器快照，补一次全量拉取
    private func schedulePullAllAnnisIfPending() {
        guard pendingPullAllAnnisFromFirestoreAfterLocalSync else { return }
        pendingPullAllAnnisFromFirestoreAfterLocalSync = false
        pullAllAnnisFromFirestoreAndMergeIntoCoreData()
    }
    
    /// 主动拉取 `annis/{coupleId}/anni` 全集并写入 Core Data（不依赖增量 documentChanges）
    private func pullAllAnnisFromFirestoreAndMergeIntoCoreData() {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            logInfo("ℹ️ [AnniManger] 全量拉取跳过：无 coupleId")
            return
        }
        guard !isLocalSyncing else {
            pendingPullAllAnnisFromFirestoreAfterLocalSync = true
            return
        }
        logInfo("🔄 [AnniManger] 全量拉取 Firestore 纪念日并合并…")
        isLocalSyncing = true
        let db = Firestore.firestore()
        db.collection("annis")
            .document(coupleId)
            .collection("anni")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    self.logError("❌ [AnniManger] 全量拉取失败: \(error.localizedDescription)")
                    self.isLocalSyncing = false
                    self.loadContent()
                    return
                }
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    self.logInfo("ℹ️ [AnniManger] Firestore 纪念日集合为空")
                    self.isLocalSyncing = false
                    self.loadContent()
                    return
                }
                let group = DispatchGroup()
                for doc in documents {
                    group.enter()
                    self.annisyncItem(documentID: doc.documentID, data: doc.data()) {
                        group.leave()
                    }
                }
                group.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }
                    self.isLocalSyncing = false
                    self.logInfo("✅ [AnniManger] 全量合并完成（\(documents.count) 条）")
                    self.loadContent()
                    self.schedulePullAllAnnisIfPending()
                }
            }
    }
    
    // MARK: - 通用同步方法（无修改）
    /// Core Data → Firebase 同步（带完成回调）
    private func annisyncModelToFirebase(model: AnniModel, completion: @escaping () -> Void) {
        guard let itemID = model.id else {
            AlertManager.showSingleButtonAlert(message: "❌ Synchronization failed: Model ID is empty", target: self)
            completion()
            return
        }
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            logInfo("ℹ️ [AnniManger] 无 coupleId，跳过 Firebase 同步（未链接或引导阶段）")
            completion()
            return
        }
        guard model.isShared else {
            logInfo("ℹ️ [AnniManger] isShared=否，跳过 Firebase 同步（仅本地）(\(model.id ?? ""))")
            completion()
            return
        }
        
        var firestoreData: [String: Any] = [
            "titleLabel": model.titleLabel ?? "",
            "targetDate": model.targetDate ?? Date(),
            "repeatDate": model.repeatDate ?? "",
            "isNever": model.isNever,
            "advanceDate": model.advanceDate ?? "",
            "isReminder": model.isReminder,
            "assignIndex": model.assignIndex,
            "wishImage": model.wishImage ?? "",
            "creationDate": model.creationDate ?? Date(),
            "creatorUUID": model.creatorUUID ?? "",
            "isShared": model.isShared,
            "serverTimestamp": FieldValue.serverTimestamp()
        ]
        
        // ✅ 同步图片 URL 数组（从 JSON 字符串解析）
        let imageURLs = getImageURLs(from: model)
        if !imageURLs.isEmpty {
            firestoreData["imageURLs"] = imageURLs
        }
        
        DispatchQueue.global(qos: .utility).async {
            let db = Firestore.firestore()
            db.collection("annis")
                .document(coupleId)
                .collection("anni")
                .document(itemID)
                .setData(firestoreData, merge: true) { [weak self] error in
                    if let error = error {
                        self?.logError("❌ 同步 Firebase 失败 (\(itemID)): \(error.localizedDescription)")
                        // ✅ 移除频繁弹窗，避免卡顿
                    } else {
                        self?.logInfo("✅ 同步 Firebase 成功 (\(itemID))")
                    }
                    completion()
                }
        }
    }
    
    /// 登记：接下来因「取消共享」从 Firestore 删除该 id 时，本机监听到 `.removed` 后保留 Core Data。
    private func registerRetainLocalAnniAfterCloudRemove(documentId: String) {
        let block = { [weak self] in
            self?.anniDocumentIdsRetainLocalWhenFirestoreRemoves.insert(documentId)
        }
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
    }
    
    /// 若 documentID 曾登记为「仅删云端、保留本机」，返回 true 并清除登记。
    private func consumeAnniRetainLocalAfterFirestoreRemove(documentID: String) -> Bool {
        if Thread.isMainThread {
            return anniDocumentIdsRetainLocalWhenFirestoreRemoves.remove(documentID) != nil
        }
        var keep = false
        DispatchQueue.main.sync {
            keep = anniDocumentIdsRetainLocalWhenFirestoreRemoves.remove(documentID) != nil
        }
        return keep
    }
    
    /// Core Data → Firebase 删除（带完成回调）
    /// - Parameter isUnshareFromCloudOnly: 为 true 时表示用户把本条改为仅本地：删 Firestore 让对方同步删掉，但本机监听器**不要**删 Core Data。
    private func annideleteModelFromFirebase(model: AnniModel, isUnshareFromCloudOnly: Bool = false, completion: @escaping () -> Void) {
        guard let itemID = model.id else {
            AlertManager.showSingleButtonAlert(message: "❌ Deletion failed: Model ID is empty", target: self)
            completion()
            return
        }
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            
            logError("❌ 删除失败：缺少 Couple ID")
            completion()
            return
        }
        
        if isUnshareFromCloudOnly {
            registerRetainLocalAnniAfterCloudRemove(documentId: itemID)
        }
        
        DispatchQueue.global(qos: .utility).async {
            let db = Firestore.firestore()
            db.collection("annis")
                .document(coupleId)
                .collection("anni")
                .document(itemID)
                .delete { [weak self] error in
                    if let error = error {
                        self?.logError("❌ Firebase 删除失败 (\(itemID)): \(error.localizedDescription)")
                    } else {
                        self?.logInfo("✅ Firebase 删除成功 (\(itemID))")
                    }
                    completion()
                }
        }
    }
    
    /// 链接成功后补传：按当前用户「在一起」日期解析确定性 id，否则按 UserDefaults 里记录的 id 查找。
    private func resolveBootRelationshipAnniModelForFirebasePush() -> AnniModel? {
        let uuid = UserManger.manager.currentUserUUID
        if let user = UserManger.manager.getUserModelByUUID(uuid),
           let rel = user.relationshipStartDate {
            let day = Calendar.current.startOfDay(for: rel)
            let id = Self.bootRelationshipAnniDocumentId(forDayStart: day)
            if let model = AnniModel.mr_findFirst(byAttribute: "id", withValue: id) as? AnniModel {
                return model
            }
        }
        if let id = UserDefaults.standard.string(forKey: Self.bootRelationshipAnniUserDefaultsKey),
           let model = AnniModel.mr_findFirst(byAttribute: "id", withValue: id) as? AnniModel {
            return model
        }
        return nil
    }
    
    /// 链接成功后补传：确保「在一起」纪念日写入 Firestore（本地已由 ensureRelationshipStartAnniAfterCoupleLinked 创建时可作为兜底再推一次）。
    private func pushRelationshipStartAnniToFirebaseIfNeeded() {
        guard CoupleStatusManager.getPartnerId() != nil else { return }
        guard let model = resolveBootRelationshipAnniModelForFirebasePush() else { return }
        annisyncModelToFirebase(model: model) { }
    }
    
    /// 引导页选择「在一起」日期：同一天 → 与伴侣共用同一文档 id（一条）；不同天 → 不同 id（各一条）；后续可在 Anni 里自行编辑。
    func upsertRelationshipStartAnniFromBoot(targetDate rawDate: Date) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.upsertRelationshipStartAnniFromBoot(targetDate: rawDate) }
            return
        }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: rawDate)
        let newId = Self.bootRelationshipAnniDocumentId(forDayStart: dayStart)
        let key = Self.bootRelationshipAnniUserDefaultsKey
        let uid = CoupleStatusManager.getUserUniqueUUID()
        let assignIdx = TaskAssignIndex.both.rawValue
        let advanceText = "No reminder"
        
        if let stored = UserDefaults.standard.string(forKey: key), stored != newId {
            if let old = AnniModel.mr_findFirst(byAttribute: "id", withValue: stored) as? AnniModel {
                removeNotificationForTask(model: old)
                deleteModel(old)
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        if let model = AnniModel.mr_findFirst(byAttribute: "id", withValue: newId) as? AnniModel {
            removeNotificationForTask(model: model)
            model.titleLabel = Self.relationshipStartAnniTitle
            model.targetDate = dayStart
            model.repeatDate = Self.relationshipStartRepeatDate
            model.isNever = false
            model.advanceDate = advanceText
            model.isReminder = false
            model.assignIndex = Int32(assignIdx)
            model.wishImage = Self.relationshipStartWishImage
            model.isShared = true
            if model.creatorUUID == nil { model.creatorUUID = uid }
            UserDefaults.standard.set(newId, forKey: key)
            NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
            saveContext()
            loadContent()
            createNotificationForTaskIfNeeded(model: model)
            logInfo("✅ [AnniManger] 已更新引导页在一起纪念日")
            return
        }
        
        guard let model = AnniModel.mr_createEntity() else {
            logError("❌ [AnniManger] 无法创建引导页在一起纪念日")
            return
        }
        model.id = newId
        UserDefaults.standard.set(newId, forKey: key)
        model.creatorUUID = uid
        model.creationDate = Date()
        model.titleLabel = Self.relationshipStartAnniTitle
        model.targetDate = dayStart
        model.repeatDate = Self.relationshipStartRepeatDate
        model.isNever = false
        model.advanceDate = advanceText
        model.isReminder = false
        model.assignIndex = Int32(assignIdx)
        model.wishImage = Self.relationshipStartWishImage
        model.isShared = true
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        createNotificationForTaskIfNeeded(model: model)
        logInfo("✅ [AnniManger] 已创建引导页在一起纪念日")
    }
    
    
    func loadContent() {
        models = AnniModel.mr_findAllSorted(by: "creationDate", ascending: true) as? [AnniModel] ?? []
        
        updatePipe.input.send(value: 1)
        
        // ✅ 防抖机制：避免频繁发送通知导致卡顿
        loadContentWorkItem?.cancel()
        
        let now = Date()
        let timeSinceLastNotification = now.timeIntervalSince(lastLoadContentTime)
        
        // ✅ 如果距离上次通知时间小于防抖间隔，延迟发送（但不超过1秒）
        let delay: TimeInterval = timeSinceLastNotification < notificationDebounceInterval ? 
            min(notificationDebounceInterval - timeSinceLastNotification, 1.0) : 0
        
        loadContentWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lastLoadContentTime = Date()
            NotificationCenter.default.post(name: AnniManger.dataDidUpdateNotification, object: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: loadContentWorkItem!)
    }
    
    func loadCurrentMonthContent() -> [AnniModel] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components)!
        let endDate = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", startOfMonth as NSDate, endDate as NSDate)
        return AnniModel.mr_findAll(with: predicate) as? [AnniModel] ?? []
    }

    func addModel(
        titleLabel: String,
        targetDate: Date?,
        repeatDate: String,
        isNever: Bool,
        advanceDate: String,
        isReminder: Bool,
        assignIndex: Int,
        imageURLs: [String], // ✅ 接收图片 URL 数组（Base64 字符串数组）
        wishImage: String,
        isShared: Bool
    ) -> AnniModel? {
        logDebug("🔍 [AnniManger] addModel 开始 - Title: \(titleLabel)")
        
        // ✅ 修复：确保在主线程执行 CoreData 操作，避免线程问题导致崩溃
        guard Thread.isMainThread else {
            var result: AnniModel?
            DispatchQueue.main.sync {
                result = self.addModel(titleLabel: titleLabel, targetDate: targetDate, repeatDate: repeatDate, isNever: isNever, advanceDate: advanceDate, isReminder: isReminder, assignIndex: assignIndex, imageURLs: imageURLs, wishImage: wishImage, isShared: isShared)
            }
            return result
        }
        
        // 使用 MagicalRecord 在默认上下文中创建实体
        guard let model = AnniModel.mr_createEntity() else {
            logError("❌ [AnniManger] 无法创建AnniModel实体")
            return nil
        }
        
        let anniID = UUID().uuidString
        model.id = anniID
        model.creatorUUID = CoupleStatusManager.getUserUniqueUUID()
        model.creationDate = Date()
        model.titleLabel = titleLabel
        model.targetDate = targetDate
        model.repeatDate = repeatDate
        model.isNever = isNever
        model.advanceDate = advanceDate
        model.isReminder = isReminder
        model.assignIndex = Int32(assignIndex)
        model.wishImage = wishImage
        model.isShared = isShared
        
        // ✅ 将图片 URL 数组转换为 JSON 字符串存储（CoreData 不支持数组）
        if !imageURLs.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: imageURLs),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                // 使用 useraddImage 字段存储 JSON 字符串的 Data
                model.useraddImage = jsonString.data(using: .utf8)
            }
        }
        
        // ✅ 修复：使用同步保存到持久化存储，确保 handleContextDidSave 被正确触发
        // 这样数据会立即同步到Firebase，避免第一次添加时无法同步的问题
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        self.createNotificationForTaskIfNeeded(model: model)
        
        logInfo("✅ [AnniManger] addModel 完成 - ID: \(anniID)")
        // 返回新创建的模型
        return model
    }
    
    // ✅ 从 AnniModel 获取图片 URL 数组
    func getImageURLs(from model: AnniModel) -> [String] {
        guard let imageData = model.useraddImage,
              let jsonString = String(data: imageData, encoding: .utf8),
              let jsonData = jsonString.data(using: .utf8),
              let imageURLs = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            return []
        }
        return imageURLs
    }
    
    
    private func createNotificationForTaskIfNeeded(model: AnniModel) {
        guard model.isReminder else {
            logInfo("ℹ️ 任务[\(model.id ?? "nil")]提醒关闭，不创建通知")
            return
        }

        // 1. 获取核心数据
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        let assignIndex = Int(model.assignIndex)
        let taskId = model.id ?? ""
        guard !taskId.isEmpty else { return }
        
        // 获取重复周期文本和目标日期
        let repeatText = model.repeatDate ?? "Never"
        let targetDate = model.targetDate ?? Date()
        
        // ✅ 修复：解析 advanceDate，计算实际的触发时间
        let advanceDate = model.advanceDate ?? "No reminder"
        
        // 对于重复任务，需要计算下一个目标日期
        let nextTargetDate: Date
        let cycle = TaskRepeatCycle.parse(from: repeatText)
        let cycleCount = TaskRepeatCycle.parseCycleCount(from: repeatText)
        
        if cycle != .never {
            // 有重复规则，计算下一个目标日期
            nextTargetDate = AnniDateCalculator.shared.calculateNextTargetDate(
                originalDate: targetDate,
                repeatText: repeatText
            )
        } else {
            // 无重复规则，使用原始目标日期
            nextTargetDate = targetDate
        }
        
        // 基于下一个目标日期计算触发时间
        guard let triggerDate = AnniDateCalculator.shared.calculateNotificationTriggerDate(
            advanceDate: advanceDate,
            targetDate: nextTargetDate
        ) else {
            logInfo("ℹ️ 任务[\(taskId)]无有效触发时间，不创建通知")
            return
        }
        
        // ✅ 修复：判断是否为全天通知（如果 advanceDate 是 "No reminder" 或无法解析，则视为全天）
        let isAllDay = model.isNever || advanceDate == "No reminder"

        // ✅ 修复：处理所有分配索引情况
        if assignIndex.isMyself {
            // 分配索引1（自己）→ 仅创建本机通知
            logInfo("ℹ️ 分配索引（自己）→ 仅创建本机通知")
            AnniNotificationManager.shared.createSingleCycleTaskNotification(
                taskId: taskId,
                title: model.wishImage ?? "纪念日提醒",
                body: model.titleLabel ?? "",
                triggerDate: triggerDate,
                isAllDay: isAllDay,
                repeatText: repeatText,
                isReminderOn: model.isReminder
            )
        } else if assignIndex.isPartner {
            guard model.isShared else {
                logInfo("ℹ️ 仅本地纪念日，不向伴侣同步通知指令")
                AnniNotificationManager.shared.createSingleCycleTaskNotification(
                    taskId: taskId,
                    title: model.wishImage ?? "纪念日提醒",
                    body: model.titleLabel ?? "",
                    triggerDate: triggerDate,
                    isAllDay: isAllDay,
                    repeatText: repeatText,
                    isReminderOn: model.isReminder
                )
                return
            }
            logInfo("ℹ️ 分配索引（伴侣）→ 仅同步到伴侣设备")
            guard !partnerUUID.isEmpty else {
                logError("❌ 伴侣UUID为空，无法同步通知")
                return
            }
            syncNotificationTaskToPartner(taskId: taskId, partnerUUID: partnerUUID, model: model, triggerDate: triggerDate, isAllDay: isAllDay, isCreate: true)
        } else if assignIndex.isBoth {
            logInfo("ℹ️ 分配索引（双方）→ 本机创建1条+（若已同步给对方）伴侣规则")
            AnniNotificationManager.shared.createSingleCycleTaskNotification(
                taskId: taskId,
                title: model.wishImage ?? "纪念日提醒",
                body: model.titleLabel ?? "",
                triggerDate: triggerDate,
                isAllDay: isAllDay,
                repeatText: repeatText,
                isReminderOn: model.isReminder
            )
            guard model.isShared, !partnerUUID.isEmpty else { return }
            syncNotificationTaskToPartner(taskId: taskId, partnerUUID: partnerUUID, model: model, triggerDate: triggerDate, isAllDay: isAllDay, isCreate: true)
        }
    }
    
    private func syncNotificationTaskToPartner(taskId: String, partnerUUID: String, model: AnniModel, triggerDate: Date, isAllDay: Bool, isCreate: Bool) {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            logError("❌ 同步通知指令失败：缺少CoupleID")
            return
        }
        
        // ✅ 修复：使用计算后的触发时间，而不是原始目标日期
        // 构建通知指令数据
        let notifyData: [String: Any] = [
             "taskId": taskId,
             "title": model.wishImage ?? "纪念日提醒",
             "body": model.titleLabel ?? "",
             "triggerDate": triggerDate, // ✅ 使用计算后的触发时间
             "isAllDay": isAllDay, // ✅ 使用计算后的全天标志
             "isReminderOn": model.isReminder,
             "repeatText": model.repeatDate ?? "Never", // 关键：同步重复规则
             "isCreate": isCreate,
             "senderUUID": CoupleStatusManager.getUserUniqueUUID(),
             "serverTimestamp": FieldValue.serverTimestamp()
         ]
        
        // 推送至Firebase：伴侣UUID专属通知指令集合
        let db = Firestore.firestore()
        db.collection("couples")
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
    
    func removeNotificationForTask(model: AnniModel) {
        let taskId = model.id ?? ""
        guard !taskId.isEmpty else { return }
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        
        // 1. 移除本机通知
        AnniNotificationManager.shared.removeTaskNotification(taskId: taskId)
        
        // 2. 已链接时向对方发「移除提醒任务」（幂等）。编辑后可能已是仅本地+assign 自己，仍需清掉对方端旧任务（例如刚从同步改为不同步）
        guard !partnerUUID.isEmpty, CoupleStatusManager.getPartnerId() != nil else { return }
        let defaultDate = model.targetDate ?? Date()
        syncNotificationTaskToPartner(
            taskId: taskId,
            partnerUUID: partnerUUID,
            model: model,
            triggerDate: defaultDate,
            isAllDay: model.isNever,
            isCreate: false
        )
    }
    
    func updateModel(_ model: AnniModel){
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
    }
    
    func AnniupdateItem(withId itemId: String, updatedData: [String: Any?]) {
          MagicalRecord.save({ [weak self] (localContext) in
              guard let self = self else { return }
              guard let model = AnniModel.mr_findFirst(byAttribute: "id", withValue: itemId, in: localContext) else {
                  self.logInfo("⚠️ 没有找到 ID 为 \(itemId) 的模型，无法更新。")
                  return
              }
              
              // 仅处理 addModel 中包含的属性，移除无关字段
              for (key, value) in updatedData {
                  switch key {
                  case "titleLabel":
                      model.titleLabel = value as? String
                  case "targetDate":
                      model.targetDate = value as? Date
                  case "repeatDate":
                      model.repeatDate = value as? String
                  case "isNever":
                      model.isNever = value as? Bool ?? false
                  case "advanceDate":
                      model.advanceDate = value as? String
                  case "isReminder":
                      model.isReminder = value as? Bool ?? false
                  case "assignIndex":
                      model.assignIndex = (value as? Int).map { Int32($0) } ?? 0
                  case "wishImage":
                      model.wishImage = value as? String
                  case "isShared":
                      model.isShared = value as? Bool ?? true
                  case "imageURLs": // ✅ 更新图片 URL 数组
                      if let imageURLs = value as? [String], !imageURLs.isEmpty {
                          if let jsonData = try? JSONSerialization.data(withJSONObject: imageURLs),
                             let jsonString = String(data: jsonData, encoding: .utf8) {
                              model.useraddImage = jsonString.data(using: .utf8)
                          }
                      } else {
                          // 如果图片数组为空，清空 useraddImage
                          model.useraddImage = nil
                      }
                  default:
                      self.logInfo("⚠️ 未知的更新键: \(key)")
                  }
              }
              
              self.logDebug("🔄 在后台上下文中更新了模型 \(itemId)。")
              
          }, completion: { [weak self] (success, error) in
              guard let self = self else { return }
              if success {
                  self.logInfo("✅ Item \(itemId) updated successfully.")
                  self.loadContent()
                  // MagicalRecord 私有队列保存时，DidSave 不一定发到 mr_default()，此处显式推/删 Firestore，保证「关同步」时对方会收到文档删除并删掉本地这一条
                  if let updatedModel = AnniModel.mr_findFirst(byAttribute: "id", withValue: itemId) as? AnniModel {
                      if updatedModel.isShared {
                          self.annisyncModelToFirebase(model: updatedModel) {
                              self.logInfo("✅ [AnniManger] 编辑后已同步到 Firestore (\(itemId))")
                          }
                      } else {
                          self.annideleteModelFromFirebase(model: updatedModel, isUnshareFromCloudOnly: true) {
                              self.logInfo("✅ [AnniManger] 已改为仅本地：云端已删，对方将移除该条；本机保留 (\(itemId))")
                          }
                      }
                      self.removeNotificationForTask(model: updatedModel)
                      self.createNotificationForTaskIfNeeded(model: updatedModel)
                  }
              } else {
                  self.logError("❌ Error updating item \(itemId): \(error?.localizedDescription ?? "Unknown error")")
              }
          })
      }
       
       func deleteModel(_ anniModel: AnniModel) {
           anniModel.mr_deleteEntity() // 修复删除逻辑
           NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
           loadContent()
       }
    
    func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
            logError("Failed to save context: \(error)")
        }
    }
    
    func fetchAnniModels() -> [AnniModel] {
        if let models = AnniModel.mr_findAllSorted(by: "creationDate", ascending: false) as? [AnniModel] {
            return models
        }
        return []
    }
       
    func annisyncItem(documentID: String, data: [String: Any], completion: @escaping () -> Void = {}) {
        MagicalRecord.save({ [weak self] (localContext) in
            guard let self = self else { return }
            var targetModel: AnniModel?
            if let existingModel = AnniModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                targetModel = existingModel
            } else if let newModel = AnniModel.mr_createEntity(in: localContext) {
                targetModel = newModel
                targetModel?.id = documentID
            }
            
            guard let model = targetModel else {
                self.logError("❌ [AnniManger] Core Data Error: Unable to create or find model \(documentID)")
                // ✅ 修复：即使创建失败，也要调用 completion，避免 localSyncGroup 死锁
                return
            }
            model.titleLabel = data["titleLabel"] as? String
            if let targetDate = data["targetDate"] as? Timestamp {
                model.targetDate = targetDate.dateValue()
            }
            
//            if let repeatDate = data["repeatDate"] as? String {
//                model.repeatDate = repeatDate.dateValue()
//            }
            
            model.repeatDate  = data["repeatDate"] as? String
            model.isNever = data["isNever"] as? Bool ?? false
            
//            if let advanceDate = data["advanceDate"] as? String {
//                model.advanceDate = advanceDate.dateValue()
//            }
            
            model.advanceDate  = data["advanceDate"] as? String
            
            model.isReminder = data["isReminder"] as? Bool ?? false
            
            // ✅ 使用安全的可选绑定，避免强制解包导致崩溃
            if let assignIndexValue = data["assignIndex"] as? Int {
                model.assignIndex = Int32(assignIndexValue)
            } else {
                model.assignIndex = 0
            }
            
            model.wishImage = data["wishImage"] as? String
            
            // ✅ 同步图片 URL 数组（转换为 JSON 字符串存储）
            if let imageURLs = data["imageURLs"] as? [String], !imageURLs.isEmpty {
                if let jsonData = try? JSONSerialization.data(withJSONObject: imageURLs),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    model.useraddImage = jsonString.data(using: .utf8)
                }
            }
            
            if let timestamp = data["serverTimestamp"] as? Timestamp {
                model.creationDate = timestamp.dateValue()
            } else {
                if model.creationDate == nil {
                    model.creationDate = Date()
                }
            }
            if let creatorUUID = data["creatorUUID"] as? String {
                model.creatorUUID = creatorUUID
            }
            model.isShared = data["isShared"] as? Bool ?? true
        }, completion: { [weak self] (success, error) in
            guard let self = self else {
                completion()
                return
            }
            if success {
                self.logDebug("🔄 Core Data Synced: Item \(documentID) processed.")
                NotificationCenter.default.post(name: AnniManger.dataDidUpdateNotification, object: nil)
            } else {
                // ✅ 修复：检查是否为关键错误，非关键错误只打印日志，不显示弹窗
                // 因为 MagicalRecord 有时候即使保存成功，也可能因为合并冲突等返回 success=false
                let nsError = error as NSError?
                let isCriticalError = nsError?.code == 133020 || // NSValidationErrorMinimum
                                    nsError?.code == 133021 || // NSValidationErrorMaximum
                                    nsError?.code == 134030 || // NSManagedObjectContextLockingError
                                    nsError?.code == 134040 || // NSPersistentStoreInvalidTypeError
                                    (nsError?.domain == "NSCocoaErrorDomain" && nsError?.code == 134030)
                
                if isCriticalError {
                    // ✅ 关键错误：显示弹窗
                    AlertManager.showSingleButtonAlert(message: "❌ Error saving sync changes to Core Data: \(error?.localizedDescription ?? "Unknown error")", target: self)
                } else {
                    // ✅ 非关键错误：只打印日志（可能是合并冲突等，数据实际已保存）
                    self.logInfo("⚠️ [AnniManger] 保存时出现非关键错误（数据可能已保存）: \(error?.localizedDescription ?? "Unknown error")")
                    // ✅ 即使 success=false，也发送通知（因为数据可能已经保存）
                    NotificationCenter.default.post(name: AnniManger.dataDidUpdateNotification, object: nil)
                }
            }
            completion() // ✅ 修复：无论成功或失败，都调用 completion
        })
    }
    
    func annideleteItem(documentID: String, completion: @escaping () -> Void = {}) {
        MagicalRecord.save({ [weak self] (localContext) in
            guard let self = self else { return }
            if let modelToDelete = AnniModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                modelToDelete.mr_deleteEntity(in: localContext)
                self.logDebug("🗑️ Core Data Synced: Deleted item \(documentID)")
            }
        }, completion: { [weak self] (success, error) in
            guard let self = self else {
                completion()
                return
            }
            if success {
                NotificationCenter.default.post(name: AnniManger.dataDidUpdateNotification, object: nil)
            } else {
                self.logError("❌ Error deleting item in Core Data: \(error?.localizedDescription ?? "Unknown error")")
            }
            completion() // ✅ 修复：无论成功或失败，都调用 completion
        })
    }
}


