//
//  PointsManger.swift
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

class PointsManger: NSObject {
    // MARK: ✅ 单例+全局常量（对齐DbManager）
    static let manager = PointsManger()
    var models = [PointsModel]()
    let updatePipe = Signal<Int, Never>.pipe()
    static let dataDidUpdateNotification = Notification.Name("DataDidUpdateNotification")
    var managedObjectContext: NSManagedObjectContext
    
    // MARK: ✅ Firebase监听+同步标记（对齐DbManager）
    private var firebaseListener: ListenerRegistration?
    private var isLocalSyncing = false
    private var needRestartListener = false
    // ✅ 记录正在同步的wish ID，避免监听器重复处理
    private var syncingWishIds = Set<String>()
    // ✅ 记录正在删除的wish ID，避免监听器重复处理
    private var deletingWishIds = Set<String>()
    
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
    
    // MARK: ✅ 初始化（对齐DbManager，移除分数逻辑）
    override init() {
        self.managedObjectContext = NSManagedObjectContext.mr_default()
        super.init()
        
        // CoreData存储路径打印
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Waves/ListModel.sqlite")
        logDebug("CoreData存储路径: \(storeURL)")
        
        // CoreData基础配置
        guard let model = NSManagedObjectModel.mr_newManagedObjectModelNamed("ListModel.momd") else {
            fatalError("Failed to load Core Data model!")
        }
        NSManagedObjectModel.mr_setDefaultManagedObjectModel(model)
        MagicalRecord.setShouldAutoCreateManagedObjectModel(false)
        MagicalRecord.setupAutoMigratingCoreDataStack()
        
        setupCoreDataChangeListener()
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
        logInfo("🔔 PointsManger: 收到断开链接通知，停止监听器")
        removeFirebaseListener()
        needRestartListener = false
        logInfo("✅ PointsManger: 断开链接处理完成")
    }
    
    @objc private func handleCoupleDidLink() {
        logInfo("🔔 PointsManger: 收到链接成功通知，准备重启监听器")
        // ✅ 延迟一小段时间，确保 partnerId 已保存到 UserDefaults
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            // ✅ 再次检查 partnerId 是否存在
            if let coupleId = CoupleStatusManager.getPartnerId() {
                self.logInfo("✅ PointsManger: partnerId 已设置 (\(coupleId))，重启监听器")
                self.setupFirebaseRealTimeListener()
                self.logInfo("✅ PointsManger: 链接成功处理完成，监听器已重启")
            } else {
                self.logInfo("⚠️ PointsManger: partnerId 未设置，延迟重启监听器")
                // ✅ 如果 partnerId 还未设置，再延迟一段时间后重试
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if let coupleId = CoupleStatusManager.getPartnerId() {
                        self.logInfo("✅ PointsManger: partnerId 已设置 (\(coupleId))，重启监听器（延迟重试）")
                        self.setupFirebaseRealTimeListener()
                    } else {
                        self.logInfo("ℹ️ PointsManger: partnerId 未设置，可能已断开链接，跳过重启监听器")
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
    
    // MARK: ✅ Firebase监听管理（对齐DbManager）
    private func setupFirebaseRealTimeListener() {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            // ✅ 修复：引导页阶段没有 coupleId 是正常的，静默跳过，不弹出错误
            logInfo("ℹ️ PointsManger: 没有 coupleId，跳过启动监听器（引导页阶段或未链接伴侣）")
            return
        }
        
        removeFirebaseListener()
        let db = Firestore.firestore()
        let itemsRef = db.collection("couples").document(coupleId).collection("wish")
        
        logInfo("🔍 [PointsManger] 启动 Firebase 实时监听器")
        logInfo("  - coupleId: \(coupleId)")
        logInfo("  - 监听路径: couples/\(coupleId)/wish")
        logInfo("  - 当前 syncingWishIds 数量: \(syncingWishIds.count)")
        logInfo("  - 当前 deletingWishIds 数量: \(deletingWishIds.count)")
        
        firebaseListener = itemsRef.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            guard let snapshot = querySnapshot, error == nil else {
                let errorMsg = error?.localizedDescription ?? "Unknown error"
                self.logError("❌ [PointsManger] Firebase 监听器错误: \(errorMsg)")
                AlertManager.showSingleButtonAlert(message: "❌ Points listener failed.：\(errorMsg)", target: self)
                return
            }
            
            // ✅ 添加调试日志：记录监听器是否正常工作
            self.logInfo("📡 [PointsManger] Firebase 监听器收到更新")
            self.logInfo("  - 文档总数: \(snapshot.documents.count)")
            self.logInfo("  - 变更数量: \(snapshot.documentChanges.count)")
            
            // ✅ 优化：检查是否有需要处理的远程更新
            // 如果所有变更都是本地同步的wish，可以跳过（避免循环同步）
            let hasRemoteUpdates = snapshot.documentChanges.contains { change in
                let documentID = change.document.documentID
                // 如果wish不在 syncingWishIds 中，说明是远程更新
                let isRemote = !self.syncingWishIds.contains(documentID) && !self.deletingWishIds.contains(documentID)
                if !isRemote {
                    self.logInfo("  - 跳过本地同步的 wish: \(documentID) (在 syncingWishIds 中)")
                }
                return isRemote
            }
            
            if !hasRemoteUpdates && !snapshot.documentChanges.isEmpty {
                self.logInfo("ℹ️ [PointsManger] 所有变更都是本地同步的wish，跳过处理（避免循环）")
                self.logInfo("  - 变更数量: \(snapshot.documentChanges.count)")
                self.logInfo("  - syncingWishIds: \(Array(self.syncingWishIds))")
                return
            }
            
            if hasRemoteUpdates {
                self.logInfo("✅ [PointsManger] 检测到远程更新，开始处理")
            }
            
            // ✅ 打印收到的变更信息
            if !snapshot.documentChanges.isEmpty {
                self.logInfo("📥 [PointsManger] 收到 Firebase 更新，变更数量: \(snapshot.documentChanges.count)")
                for change in snapshot.documentChanges {
                    self.logInfo("  - \(change.type): \(change.document.documentID)")
                }
            }
            
            // ✅ 标记为「正在进行 Firebase → Core Data 同步」，避免循环
            self.isLocalSyncing = true
            let localSyncGroup = DispatchGroup()
            
            // ✅ 本批已在 documentChanges 中处理的 ID，全量校正时不再重复同步（避免创建 1 条在对方出现 2 条）
            var processedInThisSnapshot = Set<String>()
            for change in snapshot.documentChanges {
                switch change.type {
                case .added, .modified:
                    processedInThisSnapshot.insert(change.document.documentID)
                case .removed:
                    break
                }
            }
            
            // 1️⃣ 增量：处理 documentChanges
            for documentChange in snapshot.documentChanges {
                localSyncGroup.enter()
                let documentID = documentChange.document.documentID
                let data = documentChange.document.data()
                
                switch documentChange.type {
                case .added, .modified:
                    if self.syncingWishIds.contains(documentID) {
                        self.logInfo("ℹ️ [PointsManger] 跳过正在同步的wish: \(documentID)")
                        localSyncGroup.leave()
                        continue
                    }
                    self.logInfo("🔄 [PointsManger] 同步 wish 到本地: \(documentID)")
                    self.syncWishItem(documentID: documentID, data: data) {
                        self.logInfo("✅ [PointsManger] wish 同步完成: \(documentID)")
                        localSyncGroup.leave()
                    }
                case .removed:
                    if self.deletingWishIds.contains(documentID) {
                        self.logInfo("ℹ️ [PointsManger] 跳过正在删除的wish: \(documentID)")
                        localSyncGroup.leave()
                        continue
                    }
                    self.logInfo("🗑️ [PointsManger] 删除 wish: \(documentID)")
                    self.deleteWishItem(documentID: documentID) {
                        self.logInfo("✅ [PointsManger] wish 删除完成: \(documentID)")
                        localSyncGroup.leave()
                    }
                }
            }
            
            // 2️⃣ 全量校正：用 snapshot.documents 与本地对比，避免漏同步/漏删
            // 解决：① 第一次添加的 wish 对方不刷新 ② 删除最后一条对方不消失（如重连时 documentChanges 为空）
            localSyncGroup.enter()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { localSyncGroup.leave(); return }
                let localModels = PointsModel.mr_findAll() as? [PointsModel] ?? []
                let localIds = Set(localModels.compactMap { $0.id })
                let remoteIds = Set(snapshot.documents.map { $0.documentID })
                
                // 远程有、本地没有 → 同步到本地（解决「第一次添加对方看不到」）
                // ✅ 跳过本批 documentChanges 已处理的 ID，避免同一文档被同步两次导致对方出现两条
                for doc in snapshot.documents {
                    let docId = doc.documentID
                    if processedInThisSnapshot.contains(docId) {
                        continue
                    }
                    if !localIds.contains(docId), !self.syncingWishIds.contains(docId) {
                        self.logInfo("🔄 [PointsManger] 全量校正：同步缺失的 wish: \(docId)")
                        localSyncGroup.enter()
                        self.syncWishItem(documentID: docId, data: doc.data()) {
                            localSyncGroup.leave()
                        }
                    }
                }
                // 本地有、远程没有 → 从本地删除（解决「删最后一条对方不消失」）
                for localId in localIds {
                    if !remoteIds.contains(localId), !self.deletingWishIds.contains(localId) {
                        self.logInfo("🗑️ [PointsManger] 全量校正：删除远程已不存在的 wish: \(localId)")
                        localSyncGroup.enter()
                        self.deleteWishItem(documentID: localId) {
                            localSyncGroup.leave()
                        }
                    }
                }
                localSyncGroup.leave()
            }
            
            localSyncGroup.notify(queue: .main) {
                NSManagedObjectContext.mr_default().processPendingChanges()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    self.isLocalSyncing = false
                    self.loadContent()
                    self.logInfo("✅ [PointsManger] Firebase → 本地同步完成，isLocalSyncing 已重置")
                    self.logInfo("  - 已处理 \(snapshot.documentChanges.count) 个变更")
                }
            }
        }
        logInfo("✅ [PointsManger] Firebase 实时监听器已启动，等待同步...")
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
    
    // MARK: ✅ 主动从服务器拉取愿望列表（解决：本机添加的 wish 对方设备未实时收到时，对方打开列表可补全）
    /// 当用户打开愿望列表时调用一次，从 Firebase 拉取最新列表并与本地做全量校正，避免仅依赖实时监听导致的漏更新
    func refreshWishListFromServer(completion: (() -> Void)? = nil) {
        guard let coupleId = CoupleStatusManager.getPartnerId(), !coupleId.isEmpty else {
            logInfo("ℹ️ [PointsManger] refreshWishListFromServer: 没有 coupleId，跳过")
            completion?()
            return
        }
        let db = Firestore.firestore()
        let itemsRef = db.collection("couples").document(coupleId).collection("wish")
        itemsRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else {
                completion?()
                return
            }
            if let error = error {
                self.logError("❌ [PointsManger] refreshWishListFromServer 失败: \(error.localizedDescription)")
                DispatchQueue.main.async { completion?() }
                return
            }
            guard let snapshot = snapshot else {
                DispatchQueue.main.async { completion?() }
                return
            }
            let localSyncGroup = DispatchGroup()
            let remoteIds = Set(snapshot.documents.map { $0.documentID })
            DispatchQueue.main.async {
                let localModels = PointsModel.mr_findAll() as? [PointsModel] ?? []
                let localIds = Set(localModels.compactMap { $0.id })
                for doc in snapshot.documents {
                    let docId = doc.documentID
                    if !localIds.contains(docId), !self.syncingWishIds.contains(docId) {
                        self.logInfo("🔄 [PointsManger] 补全缺失的 wish: \(docId)")
                        localSyncGroup.enter()
                        self.syncWishItem(documentID: docId, data: doc.data()) {
                            localSyncGroup.leave()
                        }
                    }
                }
                for localId in localIds {
                    if !remoteIds.contains(localId), !self.deletingWishIds.contains(localId) {
                        self.logInfo("🗑️ [PointsManger] 删除远程已不存在的 wish: \(localId)")
                        localSyncGroup.enter()
                        self.deleteWishItem(documentID: localId) {
                            localSyncGroup.leave()
                        }
                    }
                }
                localSyncGroup.notify(queue: .main) {
                    NSManagedObjectContext.mr_default().processPendingChanges()
                    self.loadContent()
                    completion?()
                }
            }
        }
    }
    
    // MARK: ✅ CoreData变更监听（仅同步基础字段，无分数逻辑）
    private func setupCoreDataChangeListener() {
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
        var syncedWishIds: [String] = [] // ✅ 记录本次同步的 ID
        
        // 1. 新增对象
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, !insertedObjects.isEmpty {
            for obj in insertedObjects {
                if let model = obj as? PointsModel {
                    if let wishID = model.id, !wishID.isEmpty {
                        syncedWishIds.append(wishID)
                        dispatchGroup.enter()
                        syncModelToFirebase(model: model) {
                            dispatchGroup.leave()
                        }
                    } else {
                        // ✅ 修复：如果 ID 为空，记录错误日志，帮助排查问题
                        logError("❌ [PointsManger] handleContextDidSave: 新增的 PointsModel 没有 ID，无法同步到 Firebase")
                        logError("  - Title: \(model.titleLabel ?? "nil")")
                        logError("  - 这可能是因为 addModel 时 ID 没有正确设置")
                    }
                }
            }
        }
        
        // 2. 更新对象
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            for obj in updatedObjects {
                if let model = obj as? PointsModel {
                    if let wishID = model.id, !wishID.isEmpty {
                        syncedWishIds.append(wishID)
                        dispatchGroup.enter()
                        syncModelToFirebase(model: model) {
                            dispatchGroup.leave()
                        }
                    } else {
                        // ✅ 修复：如果 ID 为空，记录错误日志，帮助排查问题
                        logError("❌ [PointsManger] handleContextDidSave: 更新的 PointsModel 没有 ID，无法同步到 Firebase")
                        logError("  - Title: \(model.titleLabel ?? "nil")")
                    }
                }
            }
        }
        
        // 3. 删除对象
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletedObjects.isEmpty {
            for obj in deletedObjects {
                if let model = obj as? PointsModel {
                    dispatchGroup.enter()
                    deleteModelFromFirebase(model: model) {
                        dispatchGroup.leave()
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
                for wishID in syncedWishIds {
                    self.syncingWishIds.remove(wishID)
                    self.logInfo("✅ [PointsManger] 移除同步标记: \(wishID)")
                }
                self.logInfo("✅ [PointsManger] 本地同步完成，已重置标志位，监听器恢复正常")
            }
        }
    }
    
    // MARK: ✅ CoreData → Firebase 同步（仅基础label字段）
    private func syncModelToFirebase(model: PointsModel, completion: @escaping () -> Void) {
        // ✅ 如果没有coupleId（测试环境），直接完成，不同步到Firebase
        guard let wishID = model.id, let coupleId = CoupleStatusManager.getPartnerId(), !coupleId.isEmpty else {
            logInfo("ℹ️ syncModelToFirebase: 没有coupleId，跳过Firebase同步（测试模式）")
            completion()
            return
        }
        
        // ✅ 记录正在同步的wish ID，避免监听器重复处理
        syncingWishIds.insert(wishID)
        
        // ✅ 从 CoreData 读取图片 URL 数组（直接解析 JSON Data，避免多余转换）
        var imageURLs: [String] = []
        if let imageData = model.userImageData,
           let urls = try? JSONSerialization.jsonObject(with: imageData) as? [String] {
            imageURLs = urls
            logDebug("✅ [PointsManger] 从 CoreData 读取图片URL数组，数量: \(imageURLs.count)")
        }
        
        // ✅ 同步基础字段和图片URL数组：title/notes/points/isShared/wishImage/imageURLs
        var firestoreData: [String: Any] = [
            "title": model.titleLabel ?? "",
            "notes": model.notesLabel ?? "",
            "points": model.points,
            "isShared": model.isShared,
            "wishImage": model.wishImage ?? "",
            "creationDate": Timestamp(date: model.creationDate ?? Date()),
            "serverTimestamp": FieldValue.serverTimestamp()
        ]
        
        // ✅ 添加图片URL数组到Firebase数据中
        if !imageURLs.isEmpty {
            firestoreData["imageURLs"] = imageURLs
            logDebug("✅ [PointsManger] 同步图片URL数组到Firebase，数量: \(imageURLs.count)")
        } else {
            // ✅ 如果图片数组为空，也要同步空数组，确保Firebase中的数据是最新的
            firestoreData["imageURLs"] = []
            logDebug("ℹ️ [PointsManger] 图片URL数组为空，同步空数组到Firebase")
        }
        
        logInfo("📤 [PointsManger] 同步 wish 到 Firebase: \(wishID)")
        logInfo("  - coupleId: \(coupleId)")
        logInfo("  - 同步路径: couples/\(coupleId)/wish/\(wishID)")
        logInfo("  - Title: \(model.titleLabel ?? "nil")")
        logInfo("  - Points: \(model.points)")
        logInfo("  - IsShared: \(model.isShared)")
        
        DispatchQueue.global(qos: .utility).async {
            let firestoreRef = Firestore.firestore()
                .collection("couples").document(coupleId)
                .collection("wish").document(wishID)
            
            firestoreRef.setData(firestoreData, merge: true) { [weak self] error in
                guard let self = self else {
                    completion()
                    return
                }
                
                if let error = error {
                    self.logError("❌ [PointsManger] 同步到 Firebase 失败 (\(wishID))")
                    self.logError("  - 错误描述: \(error.localizedDescription)")
                    self.logError("  - 错误代码: \((error as NSError).code)")
                    self.logError("  - 错误域: \((error as NSError).domain)")
                    // ✅ 同步失败时立即移除标记，避免永久阻塞
                    self.syncingWishIds.remove(wishID)
                    // ✅ 注意：不在这里重试，避免无限递归。如果需要重试，应该在外部调用
                } else {
                    self.logInfo("✅ [PointsManger] 同步到 Firebase 成功 (\(wishID))")
                    self.logInfo("  - 另一台设备将自动收到更新")
                    self.logInfo("  - 请检查对方设备的 Firebase 监听器是否正常工作")
                    // ✅ 注意：标记会在 handleContextDidSave 的延迟重启时移除，这里不立即移除
                    // 这样可以确保监听器重启时不会处理自己的数据
                }
                completion()
            }
        }
    }
    
    private func deleteModelFromFirebase(model: PointsModel, completion: @escaping () -> Void) {
        guard let wishID = model.id else {
            completion()
            return
        }
        deleteModelFromFirebase(wishID: wishID, completion: completion)
    }
    
    private func deleteModelFromFirebase(wishID: String, completion: @escaping () -> Void) {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            completion()
            return
        }
        
        // ✅ 记录正在删除的wish ID，避免监听器重复处理
        deletingWishIds.insert(wishID)
        
        DispatchQueue.global(qos: .utility).async {
            Firestore.firestore()
                .collection("couples").document(coupleId)
                .collection("wish").document(wishID)
                .delete { [weak self] error in
                    if let error = error {
                        self?.logError("❌ Points Firebase 删除失败 (\(wishID)): \(error.localizedDescription)")
                        // ✅ 删除失败时立即移除标记，避免永久阻塞
                        self?.deletingWishIds.remove(wishID)
                    } else {
                        self?.logInfo("✅ Points Firebase 删除成功 (\(wishID))")
                        // ✅ 延迟移除标记（给监听器一些时间处理，避免重复删除）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.deletingWishIds.remove(wishID)
                        }
                    }
                    completion()
                }
        }
    }
    
    // MARK: ✅ Firebase → CoreData 同步（仅基础label字段）
    func syncWishItem(documentID: String, data: [String: Any], completion: @escaping () -> Void) {
        logInfo("🔄 [PointsManger] syncWishItem 开始 - DocumentID: \(documentID)")
        logInfo("  - Title: \(data["title"] as? String ?? "nil")")
        logInfo("  - Points: \(data["points"] ?? "nil")")
        
        MagicalRecord.save({ [weak self] (localContext) in
            guard let self = self else { return }
            var targetModel: PointsModel?
            let isNewModel: Bool
            if let existingModel = PointsModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                targetModel = existingModel
                isNewModel = false
                self.logInfo("  - 找到已存在的 PointsModel: \(documentID)")
            } else if let newModel = PointsModel.mr_createEntity(in: localContext) {
                targetModel = newModel
                newModel.id = documentID
                isNewModel = true
                self.logInfo("  - 创建新的 PointsModel: \(documentID)")
            } else {
                self.logError("⚠️ [PointsManger] 无法创建或找到 PointsModel: \(documentID)")
                completion()
                return
            }
            guard let model = targetModel else {
                self.logError("⚠️ [PointsManger] targetModel 为 nil: \(documentID)")
                completion()
                return
            }
            
            // ✅ 数据验证和同步基础字段
            // 1. 标题（允许为空，但记录日志）
            model.titleLabel = data["title"] as? String ?? ""
            if model.titleLabel?.isEmpty == true {
                self.logInfo("⚠️ [PointsManger] 标题为空: \(documentID)")
            }
            
            // 2. 备注（可选字段）
            model.notesLabel = data["notes"] as? String ?? ""
            
            // 3. 分数（确保是有效数字）
            if let pointsValue = data["points"] {
                if let pointsNumber = pointsValue as? NSNumber {
                    model.points = pointsNumber.int32Value
                } else if let pointsInt = pointsValue as? Int {
                    model.points = Int32(pointsInt)
                } else if let pointsString = pointsValue as? String, let pointsInt = Int32(pointsString) {
                    model.points = pointsInt
                } else {
                    self.logInfo("⚠️ [PointsManger] 分数格式无效，使用默认值 0: \(pointsValue)")
                    model.points = 0
                }
            } else {
                model.points = 0
            }
            
            // 4. 共享状态
            model.isShared = data["isShared"] as? Bool ?? false
            
            // 5. 愿望图标
            model.wishImage = data["wishImage"] as? String ?? ""
            
            // ✅ 同步图片 URL 数组（转换为 JSON 字符串存储）
            if let imageURLs = data["imageURLs"] as? [String] {
                if !imageURLs.isEmpty {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: imageURLs)
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            model.userImageData = jsonString.data(using: .utf8)
                            self.logDebug("✅ [PointsManger] 同步图片数组成功，数量: \(imageURLs.count)")
                        }
                    } catch {
                        self.logError("⚠️ [PointsManger] 图片数组 JSON 序列化失败: \(error.localizedDescription)")
                    }
                } else {
                    // ✅ 修复：如果图片数组为空，清空 userImageData
                    model.userImageData = nil
                    self.logDebug("ℹ️ [PointsManger] 图片数组为空，清空 userImageData")
                }
            }
            
            // 6. 创建日期
            if let creationDate = data["creationDate"] as? Timestamp {
                model.creationDate = creationDate.dateValue()
            } else if let serverTimestamp = data["serverTimestamp"] as? Timestamp {
                model.creationDate = serverTimestamp.dateValue()
            } else if model.creationDate == nil {
                model.creationDate = Date()
            }
            
            // ✅ 确保 ID 已设置
            if model.id == nil || model.id?.isEmpty == true {
                model.id = documentID
            }
            
            self.logDebug("🔍 [PointsManger] 准备保存 WishItem 到 CoreData")
            self.logDebug("  - DocumentID: \(documentID)")
            self.logDebug("  - Title: \(model.titleLabel ?? "nil")")
            self.logDebug("  - Points: \(model.points)")
            self.logDebug("  - IsShared: \(model.isShared)")
        }, completion: { [weak self] (success, error) in
            guard let self = self else { return }
            if success {
                self.logInfo("✅ [PointsManger] 同步 WishItem 到 CoreData 成功: \(documentID)")
                self.logInfo("  - 数据已保存到本地，UI 将自动更新")
                // ✅ 修复：确保在主线程发送通知，并确保 Core Data 上下文已保存
                // ✅ 重要：延迟一小段时间，确保 CoreData 的保存通知已经处理完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // ✅ 确保主上下文已保存，触发 NSFetchedResultsController 更新
                    let mainContext = NSManagedObjectContext.mr_default()
                    mainContext.processPendingChanges()
                    
                    // ✅ 强制合并所有待处理的更改，确保 NSFetchedResultsController 能检测到变化
                    do {
                        try mainContext.save()
                        self.logInfo("  - 主上下文已保存，NSFetchedResultsController 应该会检测到变化")
                    } catch {
                        self.logError("  - 主上下文保存失败: \(error.localizedDescription)")
                    }
                    
                    // ✅ 强制刷新 NSFetchedResultsController，确保 UI 更新
                    NotificationCenter.default.post(name: PointsManger.dataDidUpdateNotification, object: nil)
                    self.logInfo("  - 已发送 dataDidUpdateNotification 通知，UI 应该会更新")
                    self.logInfo("  - 当前 isLocalSyncing 状态: \(self.isLocalSyncing)")
                }
            } else {
                // ✅ 详细的错误处理
                let errorMessage = error?.localizedDescription ?? "Unknown error"
                let nsError = error as NSError?
                
                self.logError("❌ [PointsManger] 同步 WishItem 到 CoreData 失败")
                self.logError("  - DocumentID: \(documentID)")
                self.logError("  - 错误描述: \(errorMessage)")
                
                if let nsError = nsError {
                    self.logError("  - 错误代码: \(nsError.code)")
                    self.logError("  - 错误域: \(nsError.domain)")
                    self.logError("  - 错误详情: \(nsError.userInfo)")
                    
                    // ✅ 检查常见的 CoreData 错误
                    if nsError.code == 133020 { // NSValidationErrorMinimum
                        self.logError("  - ⚠️ 数据验证错误：字段值不符合约束条件")
                    } else if nsError.code == 133021 { // NSValidationErrorMaximum
                        self.logError("  - ⚠️ 数据验证错误：字段值超出最大限制")
                    } else if nsError.code == 134030 { // NSManagedObjectContextLockingError
                        self.logError("  - ⚠️ CoreData 上下文锁定错误：可能是在错误的线程上操作")
                    } else if nsError.code == 134040 { // NSPersistentStoreInvalidTypeError
                        self.logError("  - ⚠️ 持久化存储类型错误")
                    } else if nsError.domain == "NSCocoaErrorDomain" {
                        self.logError("  - ⚠️ Cocoa 错误域：可能是数据格式问题")
                    }
                    
                    // ✅ 优化：检查是否为关键错误，非关键错误只打印日志，不显示弹窗
                    // 因为 MagicalRecord 有时候即使保存成功，也可能因为合并冲突等返回 success=false
                    let isCriticalError = nsError.code == 133020 || // NSValidationErrorMinimum
                                        nsError.code == 133021 || // NSValidationErrorMaximum
                                        nsError.code == 134040 || // NSPersistentStoreInvalidTypeError
                                        (nsError.domain == "NSCocoaErrorDomain" && nsError.code != 133000 && nsError.code != 134030)
                    
                    // ✅ 非关键错误（合并冲突、上下文问题等）
                    let isNonCriticalError = nsError.code == 133000 || // NSErrorMergePolicyError（合并冲突）
                                           nsError.code == 134030 // NSManagedObjectContextLockingError（上下文锁定）
                    
                    if isCriticalError {
                        // ✅ 关键错误：显示弹窗
                        DispatchQueue.main.async {
                            AlertManager.showSingleButtonAlert(
                                message: "❌ 同步 Wish 数据到本地失败: \(errorMessage)",
                                target: nil
                            )
                        }
                    } else if isNonCriticalError {
                        // ✅ 非关键错误：只打印日志（数据可能已保存）
                        self.logInfo("ℹ️ [PointsManger] 保存时出现非关键错误（数据可能已保存）: \(errorMessage)")
                        // ✅ 即使 success=false，也发送通知（因为数据可能已经保存）
                        NotificationCenter.default.post(name: PointsManger.dataDidUpdateNotification, object: nil)
                    } else {
                        // ✅ 其他未知错误：只打印日志，不显示弹窗
                        self.logInfo("⚠️ [PointsManger] 保存时出现未知错误（数据可能已保存）: \(errorMessage)")
                        // ✅ 即使 success=false，也发送通知（因为数据可能已经保存）
                        NotificationCenter.default.post(name: PointsManger.dataDidUpdateNotification, object: nil)
                    }
                } else {
                    // ✅ 对于未知错误（error 为 nil），只打印日志，不显示弹窗
                    // 因为可能是 MagicalRecord 的内部问题，数据可能已经保存
                    self.logInfo("⚠️ [PointsManger] 保存时出现未知错误（error 为 nil，数据可能已保存）")
                    // ✅ 即使 success=false，也发送通知（因为数据可能已经保存）
                    NotificationCenter.default.post(name: PointsManger.dataDidUpdateNotification, object: nil)
                }
            }
            completion()
        })
    }
    
    // MARK: ✅ Firebase → CoreData 删除
    func deleteWishItem(documentID: String, completion: @escaping () -> Void) {
        MagicalRecord.save({ [weak self] (localContext) in
            guard let self = self else { return }
            if let modelToDelete = PointsModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                modelToDelete.mr_deleteEntity(in: localContext)
                self.logInfo("✅ [PointsManger] 从 CoreData 删除 WishItem: \(documentID)")
            } else {
                // ✅ 如果本地已经没有这个wish（可能已经被删除），不报错，只记录日志
                self.logInfo("ℹ️ [PointsManger] WishItem 不存在于本地，可能已被删除: \(documentID)")
            }
        }, completion: { [weak self] (success, error) in
            guard let self = self else {
                completion()
                return
            }
            if success {
                NotificationCenter.default.post(name: PointsManger.dataDidUpdateNotification, object: nil)
            } else {
                // ✅ 优化：如果删除失败是因为对象不存在，不显示错误（可能是重复删除）
                let nsError = error as NSError?
                let isObjectNotFound = nsError?.code == 133000 // NSErrorMergePolicyError 或其他相关错误
                
                if !isObjectNotFound {
                    self.logError("❌ Error deleting WishItem in Core Data: \(error?.localizedDescription ?? "Unknown error")")
                } else {
                    self.logInfo("ℹ️ [PointsManger] 删除失败，但可能是对象不存在（已忽略）: \(documentID)")
                }
            }
            completion()
        })
    }
    
    // ✅ 防抖机制：避免频繁发送通知导致卡顿
    private var loadContentWorkItem: DispatchWorkItem?
    private var lastLoadContentTime: Date = Date.distantPast
    private let notificationDebounceInterval: TimeInterval = 0.5 // ✅ 防抖间隔：0.5秒
    
    // MARK: ✅ 对外API（仅基础字段增删改查）
    func loadContent() {
        models = PointsModel.mr_findAllSorted(by: "creationDate", ascending: true) as? [PointsModel] ?? []
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
            NotificationCenter.default.post(name: Self.dataDidUpdateNotification, object: nil)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: loadContentWorkItem!)
    }
    
    func loadCurrentMonthContent() -> [PointsModel] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components)!
        let endDate = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", startOfMonth as NSDate, endDate as NSDate)
        return PointsModel.mr_findAll(with: predicate) as? [PointsModel] ?? []
    }
    
    func addModel(
        titleLabel: String,
        notesLabel: String,
        imageURLs: [String], // ✅ 改为接收图片 URL 数组（Base64 字符串数组）
        points: Int,
        isShared: Bool,
        wishImage: String
    ) -> PointsModel? {
        logDebug("🔍 [PointsManger] addModel 开始 - Title: \(titleLabel), Points: \(points), Images: \(imageURLs.count)")
        
        // ✅ 修复：确保在主线程执行 CoreData 操作，避免线程问题导致崩溃
        guard Thread.isMainThread else {
            var result: PointsModel?
            DispatchQueue.main.sync {
                result = self.addModel(titleLabel: titleLabel, notesLabel: notesLabel, imageURLs: imageURLs, points: points, isShared: isShared, wishImage: wishImage)
            }
            return result
        }
        
        guard let model = PointsModel.mr_createEntity() else {
            logError("❌ [PointsManger] 无法创建PointsModel实体")
            return nil
        }
        
        let wishID = UUID().uuidString
        model.id = wishID
        // ✅ 修复：验证 ID 是否被正确设置
        guard model.id == wishID, !wishID.isEmpty else {
            logError("❌ [PointsManger] addModel: ID 设置失败，wishID: \(wishID)")
            model.mr_deleteEntity()
            return nil
        }
        model.creationDate = Date()
        model.titleLabel = titleLabel
        model.notesLabel = notesLabel
        
        // ✅ 将图片 URL 数组转换为 JSON 字符串存储（CoreData 不支持数组）
        if !imageURLs.isEmpty {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: imageURLs, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    model.userImageData = jsonString.data(using: .utf8)
                }
            } catch {
                logError("❌ [PointsManger] JSON序列化失败: \(error.localizedDescription)")
            }
        }
        
        model.points = Int32(points)
        model.isShared = isShared
        model.wishImage = wishImage
        
        // ✅ 修复：使用同步保存到持久化存储，确保 handleContextDidSave 被正确触发
        // 这样数据会立即同步到Firebase，避免第一次添加时无法同步的问题
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        
        logInfo("✅ [PointsManger] addModel 完成 - ID: \(wishID)")
        return model
    }
    
    // ✅ 从 PointsModel 获取图片 URL 数组
    func getImageURLs(from model: PointsModel) -> [String] {
        // ✅ 修复：确保在主线程访问 CoreData 对象属性
        guard Thread.isMainThread else {
            var result: [String] = []
            DispatchQueue.main.sync {
                result = self.getImageURLs(from: model)
            }
            return result
        }
        
        guard let imageData = model.userImageData else {
            logInfo("⚠️ [PointsManger] getImageURLs - userImageData 为 nil")
            return []
        }
        
        // ✅ 直接解析 JSON Data，不需要先转换为字符串再转回来
        guard let imageURLs = try? JSONSerialization.jsonObject(with: imageData) as? [String] else {
            logError("⚠️ [PointsManger] getImageURLs - JSON 解析失败")
            // ✅ 添加调试信息：打印前100字节的十六进制，帮助排查问题
            let preview = imageData.prefix(100).map { String(format: "%02x", $0) }.joined()
            logDebug("  - 数据预览（前100字节）: \(preview)")
            if let debugString = String(data: imageData, encoding: .utf8) {
                logDebug("  - 字符串预览: \(String(debugString.prefix(200)))")
            }
            return []
        }
        
        logDebug("✅ [PointsManger] getImageURLs - 成功获取 \(imageURLs.count) 张图片")
        return imageURLs
    }
    
    func updateModel(_ model: PointsModel) {
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        
        syncModelToFirebase(model: model) { [weak self] in
            self?.loadContent()
        }
    }
    
    func PointsupdateItem(withId itemId: String, updatedData: [String: Any?]) {
        MagicalRecord.save({ [weak self] localContext in
            guard let self = self else { return }
            guard let model = PointsModel.mr_findFirst(byAttribute: "id", withValue: itemId, in: localContext) else {
                self.logError("⚠️ 未找到WishItem(\(itemId))，无法更新")
                return
            }
            // 仅更新基础label相关字段
            for (key, value) in updatedData {
                switch key {
                case "titleLabel": model.titleLabel = value as? String
                case "notesLabel": model.notesLabel = value as? String
                case "userImageData": model.userImageData = value as? Data
                case "points": model.points = (value as? Int).map { Int32($0) } ?? 0
                case "isShared": model.isShared = value as? Bool ?? false
                case "wishImage": model.wishImage = value as? String
                case "imageURLs": // ✅ 更新图片 URL 数组
                    if let imageURLs = value as? [String], !imageURLs.isEmpty {
                        if let jsonData = try? JSONSerialization.data(withJSONObject: imageURLs),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            model.userImageData = jsonString.data(using: .utf8)
                        }
                    } else {
                        // 如果图片数组为空，清空 userImageData
                        model.userImageData = nil
                    }
                default: break
                }
            }
        }, completion: { [weak self] success, error in
            guard let self = self else { return }
            if success, let updatedModel = PointsModel.mr_findFirst(byAttribute: "id", withValue: itemId) as? PointsModel {
                self.syncModelToFirebase(model: updatedModel) { }
            } else {
                self.logError("❌ WishItem更新失败：\(error?.localizedDescription ?? "未知错误")")
            }
        })
    }
    
    func deleteModel(_ pointsModel: PointsModel) {
        // ✅ 修复：删除CoreData数据，handleContextDidSave会自动同步到Firebase
        // 不需要手动调用deleteModelFromFirebase，避免重复删除
        guard let wishID = pointsModel.id else {
            logError("⚠️ [PointsManger] deleteModel: wishID为空，无法删除")
            return
        }
        
        logDebug("🔍 [PointsManger] deleteModel 开始 - ID: \(wishID)")
        pointsModel.mr_deleteEntity()
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        
        // ✅ 注意：deleteModelFromFirebase 会由 handleContextDidSave 自动调用
        // 不需要手动调用，避免重复删除和监听器冲突
        logInfo("✅ [PointsManger] deleteModel 完成 - ID: \(wishID)，等待handleContextDidSave同步到Firebase")
    }
    
    func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
            logError("❌ 上下文保存失败：\(error)")
        }
    }
    
    func fetchPointsModels() -> [PointsModel] {
        return PointsModel.mr_findAllSorted(by: "creationDate", ascending: false) as? [PointsModel] ?? []
    }
    
}
