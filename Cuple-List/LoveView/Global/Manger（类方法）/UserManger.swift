//
//  UserManger.swift
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

class UserManger: NSObject {
    static let manager = UserManger()
    var models = [UserModel]()
    let updatePipe = Signal<Int, Never>.pipe()
    static let dataDidUpdateNotification = Notification.Name("DataDidUpdateNotification")
    /// 仅在用户修改头像后发送，用于各页只在此刻刷新头像，避免因其他数据变更导致频繁刷新
    static let avatarDidUpdateNotification = Notification.Name("AvatarDidUpdateNotification")
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
    
    private var firebaseListener: ListenerRegistration?  // 监听自己的用户信息
    private var partnerFirebaseListener: ListenerRegistration?  // ✅ 新增：监听伴侣的用户信息
    private var isLocalSyncing = false
    private var needRestartListener = false
    private var lastSkipLogTime: Date? // ✅ 用于防抖日志打印
    private var isLocalSyncingTimeoutWorkItem: DispatchWorkItem? // ✅ 超时保护
    
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
    
    // 新增：当前用户唯一UUID
    var currentUserUUID: String {
        return CoupleStatusManager.getUserUniqueUUID()
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
        
        // 新增：自动检查并创建UUID关联的默认用户记录（避免无用户数据时UUID未存储）
        autoCreateUUIDUserRecord()
        
        // ✅ 监听断开链接通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleDidUnlink),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
    }
    
    @objc private func handleCoupleDidUnlink() {
        logInfo("🔔 UserManger: 收到断开链接通知，停止监听器")
        removeFirebaseListener()
        needRestartListener = false
        logInfo("✅ UserManger: 断开链接处理完成")
    }
    
    /// 被动端：本地清理完成后 present「已被对方断开」专用页（不进入 CheekBootPageView）
    private func presentPartnerUnlinkedLinkPage() {
        let vc = DisconnectedByPartnerViewController()
        vc.modalPresentationStyle = .fullScreen
        var top = UIViewController.getCurrentViewController(base: nil)
        if top == nil {
            // ✅ 备用：从 keyWindow.rootViewController 获取
            if let keyWindow = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow }),
               let root = keyWindow.rootViewController {
                top = root
                logInfo("ℹ️ UserManger: getCurrentViewController 返回 nil，使用 keyWindow.rootViewController")
            }
        }
        guard let target = top else {
            logInfo("⚠️ UserManger: 无法获取 topVC，跳过 present 被断开页")
            return
        }
        if target.presentedViewController != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                var t = UIViewController.getCurrentViewController(base: nil)
                if t == nil, let keyWindow = UIApplication.shared.connectedScenes
                    .filter({ $0.activationState == .foregroundActive })
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows
                    .first(where: { $0.isKeyWindow }),
                   let root = keyWindow.rootViewController {
                    t = root
                }
                guard let presenter = t else { return }
                let delayedVC = DisconnectedByPartnerViewController()
                delayedVC.modalPresentationStyle = .fullScreen
                if presenter.presentedViewController != nil {
                    presenter.presentedViewController?.present(delayedVC, animated: true)
                } else {
                    presenter.present(delayedVC, animated: true)
                }
                self.logInfo("✅ UserManger: 延迟后已 present DisconnectedByPartnerViewController")
            }
            return
        }
        target.present(vc, animated: true)
        logInfo("✅ UserManger: 已 present DisconnectedByPartnerViewController（被对方断开）")
    }
    
    deinit {
        // 销毁时移除监听，避免内存泄漏
        NotificationCenter.default.removeObserver(self)
        removeFirebaseListener()
        // ✅ 取消待执行的通知任务
        loadContentWorkItem?.cancel()
        loadContentWorkItem = nil
    }
    
    private func setupFirebaseRealTimeListener() {
        removeFirebaseListener()
        
        // ✅ 简化：只使用 UUID 路径，每个设备只监听自己的用户信息
        let userUUID = currentUserUUID
        guard !userUUID.isEmpty else {
            AlertManager.showSingleButtonAlert(message: "❌ Unable to start Waves listener: Missing user UUID", target: self)
            return
        }
        
        let db = Firestore.firestore()
        // ✅ 优化：只监听自己的 UUID 路径：users/{UUID}（简化路径，去掉 userInfo 子集合）
        let itemsRef = db.collection("users")
            .document(userUUID)
        
        // 注册实时监听（监听单个文档，而不是集合）
        firebaseListener = itemsRef.addSnapshotListener { [weak self] documentSnapshot, error in
            guard let self = self else { return }
            guard let snapshot = documentSnapshot, error == nil else {
                AlertManager.showSingleButtonAlert(message: "❌ Waves listener failed：\(error?.localizedDescription ?? "Unknown error")", target: self)
                return
            }
            
            // ✅ 优化：如果是本地同步导致的更新，直接跳过（避免循环同步）
            if self.isLocalSyncing {
                // ✅ 静默跳过，不打印日志（避免日志刷屏）
                return
            }
            
            // ✅ 只同步自己的用户信息（不处理伴侣信息）
            guard snapshot.exists, let data = snapshot.data() else {
                self.logInfo("ℹ️ UserManger: 自己的用户信息文档不存在")
                return
            }
            
            // ✅ 标记为「正在进行 Firebase → Core Data 同步」，避免循环
            self.isLocalSyncing = true
            
            // ✅ 添加超时保护：10秒后强制重置标志位
            self.isLocalSyncingTimeoutWorkItem?.cancel()
            self.isLocalSyncingTimeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.isLocalSyncing {
                    self.logInfo("⚠️ UserManger: 本地同步超时，强制重置标志位")
                    self.isLocalSyncing = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: self.isLocalSyncingTimeoutWorkItem!)
            
            let userUUID = data["userUUID"] as? String ?? self.currentUserUUID
            let userName = data["userName"] as? String ?? "未知"
            self.logInfo("📝 UserManger: 收到自己的用户信息更新 - UUID: \(userUUID), 名字: \(userName)")
            
            // ✅ 修复：确保在主线程执行 CoreData 操作
            DispatchQueue.main.async {
                self.syncItem(documentID: userUUID, data: data) {
                    // ✅ 确保标志被重置（即使出错也要重置）
                    DispatchQueue.main.async {
                        self.isLocalSyncingTimeoutWorkItem?.cancel()
                        self.isLocalSyncing = false
                    }
                    self.logInfo("✅ UserManger: 自己的用户信息同步完成，已刷新本地数据并发送通知")
                    // ✅ 注意：syncItem 内部已经调用了 loadContent()，loadContent() 会发送通知，这里不需要重复发送
                }
            }
        }
        
        logInfo("✅ Firebase 用户信息实时监听已启动（UUID：\(userUUID)）")
        logInfo("✅ 优化：监听路径：users/\(userUUID)（简化路径，去掉 userInfo 子集合）")
        
        // ✅ 新增：同时监听伴侣的用户信息（用于实时更新对方的名字和头像）
        setupPartnerFirebaseListener()
    }
    
    // ✅ 新增：监听伴侣的用户信息（实时同步对方的名字和头像）
    private func setupPartnerFirebaseListener() {
        // 先移除旧的监听
        partnerFirebaseListener?.remove()
        partnerFirebaseListener = nil
        
        // 获取伴侣UUID
        let (_, partnerUser) = getCoupleUsers()
        guard let partnerUUID = partnerUser?.id, !partnerUUID.isEmpty else {
            logInfo("ℹ️ UserManger: 未找到伴侣UUID，尝试从 couples 表获取")
            // ✅ 如果当前没有伴侣信息，尝试从 couples 表获取
            if let coupleId = CoupleStatusManager.getPartnerId() {
                let db = Firestore.firestore()
                db.collection("couples").document(coupleId).getDocument { [weak self] snapshot, error in
                    guard let self = self,
                          let snapshot = snapshot, snapshot.exists, error == nil,
                          let data = snapshot.data() else {
                        return
                    }
                    let initiatorUUID = data["initiatorUserId"] as? String ?? ""
                    let partnerUserId = data["partnerUserId"] as? String ?? ""
                    let currentUUID = self.currentUserUUID
                    let actualPartnerUUID = (currentUUID == initiatorUUID) ? partnerUserId : initiatorUUID
                    
                    if !actualPartnerUUID.isEmpty && actualPartnerUUID != currentUUID {
                        self.logInfo("✅ UserManger: 从 couples 获取到伴侣UUID，开始监听: \(actualPartnerUUID)")
                        self.startPartnerListener(partnerUUID: actualPartnerUUID)
                    }
                }
            }
            return
        }
        
        startPartnerListener(partnerUUID: partnerUUID)
    }
    
    // ✅ 新增：启动伴侣信息监听
    private func startPartnerListener(partnerUUID: String) {
        let db = Firestore.firestore()
        let partnerRef = db.collection("users").document(partnerUUID)
        
        partnerFirebaseListener = partnerRef.addSnapshotListener { [weak self] documentSnapshot, error in
            guard let self = self else { return }
            guard let snapshot = documentSnapshot, error == nil else {
                self.logError("❌ UserManger: 监听伴侣信息失败：\(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            guard snapshot.exists, let data = snapshot.data() else {
                self.logInfo("ℹ️ UserManger: 伴侣信息文档不存在")
                return
            }
            
            let partnerName = data["userName"] as? String ?? "未知"
            let partnerIsInLinkedState = data["isInLinkedState"] as? Bool ?? false
            let isFromCache = snapshot.metadata.isFromCache
            self.logInfo("📝 UserManger: 收到伴侣信息更新 - UUID: \(partnerUUID), 名字: \(partnerName), isInLinkedState: \(partnerIsInLinkedState), isFromCache: \(isFromCache)")
            
            // ✅ 关键：先处理「被对方断开」检测，不受 isLocalSyncing 影响，避免漏弹
            
            // ✅ 修复：只有在确认伴侣真正断开链接时才清除状态
            // 检查条件：1. 伴侣的 isInLinkedState 为 false 2. 当前用户已链接 3. partnerId 存在 4. 不在「链接后宽限期」内
            // 5. 数据来自服务器（非缓存）时直接处理；若来自缓存则用 getDocument(server) 二次确认，避免漏弹「被对方断开」页
            let notInGracePeriod = !CoupleStatusManager.shared.isWithinLinkGracePeriod(seconds: 20)
            let shouldCheckUnlink = !partnerIsInLinkedState && CoupleStatusManager.shared.isUserLinked && CoupleStatusManager.getPartnerId() != nil && notInGracePeriod
            
            if shouldCheckUnlink {
                let confirmAndPresentUnlinked: () -> Void = { [weak self] in
                    guard let self = self else { return }
                    if CoupleStatusManager.shared.unlinkInitiatedByCurrentUser { return }
                    CoupleStatusManager.shared.resetAllStatus()
                    UserDefaults.standard.set(false, forKey: "isCoupleLinked")
                    UserDefaults.standard.synchronize()
                    UnlinkViewController.deleteAllLocalSharedDataForUnlink()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.presentPartnerUnlinkedLinkPage()
                    }
                }
                if !isFromCache {
                    self.logInfo("⚠️ UserManger: 检测到伴侣isInLinkedState=false（服务端），对方已断开链接")
                    DispatchQueue.main.async { confirmAndPresentUnlinked() }
                } else {
                    // ✅ 来自缓存时用服务端二次确认，避免漏弹
                    partnerRef.getDocument(source: .server) { [weak self] serverSnapshot, serverError in
                        guard let self = self else { return }
                        if serverError != nil { return }
                        guard let snap = serverSnapshot, snap.exists,
                              let serverData = snap.data(),
                              (serverData["isInLinkedState"] as? Bool ?? true) == false else { return }
                        self.logInfo("⚠️ UserManger: 检测到伴侣isInLinkedState=false（缓存+服务端确认），对方已断开链接")
                        DispatchQueue.main.async { confirmAndPresentUnlinked() }
                    }
                }
                // ✅ 被对方断开时不再同步伴侣数据到 CoreData，直接 return
                return
            }
            if partnerIsInLinkedState && !CoupleStatusManager.shared.isUserLinked {
                // ✅ 修复：如果伴侣的 isInLinkedState 为 true，但当前用户未链接，可能是数据不一致
                // 这种情况下不执行任何操作，避免错误地清除状态
                self.logInfo("ℹ️ UserManger: 检测到数据不一致 - 伴侣isInLinkedState=true，但当前用户未链接，跳过处理")
            }
            
            // ✅ 优化：同步到 CoreData 时检查 isLocalSyncing，避免循环同步（「被对方断开」已在上方单独处理）
            guard !self.isLocalSyncing else { return }
            self.isLocalSyncing = true
            self.isLocalSyncingTimeoutWorkItem?.cancel()
            self.isLocalSyncingTimeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.isLocalSyncing {
                    self.logInfo("⚠️ UserManger: 本地同步超时，强制重置标志位")
                    self.isLocalSyncing = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: self.isLocalSyncingTimeoutWorkItem!)
            
            // ✅ 确保在主线程执行 CoreData 操作
            DispatchQueue.main.async {
                self.syncItem(documentID: partnerUUID, data: data) {
                    // ✅ 确保标志被重置（即使出错也要重置）
                    DispatchQueue.main.async {
                        self.isLocalSyncingTimeoutWorkItem?.cancel()
                        self.isLocalSyncing = false
                    }
                    self.logInfo("✅ UserManger: 伴侣信息同步完成，已刷新本地数据并发送通知")
                    // ✅ 注意：syncItem 内部已经调用了 loadContent()，loadContent() 会发送通知，这里不需要重复发送
                }
            }
        }
        
        logInfo("✅ Firebase 伴侣信息实时监听已启动（伴侣UUID：\(partnerUUID)）")
    }
    
    private func removeFirebaseListener() {
        firebaseListener?.remove()
        firebaseListener = nil
        partnerFirebaseListener?.remove()  // ✅ 修复：同时移除伴侣信息监听
        partnerFirebaseListener = nil
        logInfo("✅ Firebase 用户信息监听已移除（用户UUID：\(currentUserUUID)）")
    }
    
    private func restartFirebaseListener() {
        if needRestartListener {
            setupFirebaseRealTimeListener()
            needRestartListener = false
        }
    }
    
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
        
        // ✅ 先检查是否有 UserModel 需要同步
        var hasUserModelChanges = false
        
        // 检查新增对象
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, !insertedObjects.isEmpty {
            hasUserModelChanges = insertedObjects.contains { $0 is UserModel }
        }
        
        // 检查更新对象
        if !hasUserModelChanges, let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            hasUserModelChanges = updatedObjects.contains { $0 is UserModel }
        }
        
        // 检查删除对象
        if !hasUserModelChanges, let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletedObjects.isEmpty {
            hasUserModelChanges = deletedObjects.contains { $0 is UserModel }
        }
        
        // ✅ 如果没有 UserModel 的变化，直接返回（不设置 isLocalSyncing）
        guard hasUserModelChanges else {
            return
        }
        
        // ✅ 优化方案1：不移除和重启监听器，而是使用标志位暂停监听
        // 设置标志位，让监听器回调跳过处理（避免循环同步）
        isLocalSyncing = true
        
        // 处理新增/更新/删除
        let dispatchGroup = DispatchGroup()
        
        // 1. 新增对象
        if let insertedObjects = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, !insertedObjects.isEmpty {
            for obj in insertedObjects {
                if let model = obj as? UserModel {
                    dispatchGroup.enter()
                    syncModelToFirebase(model: model) {
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        // 2. 更新对象
        if let updatedObjects = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, !updatedObjects.isEmpty {
            for obj in updatedObjects {
                if let model = obj as? UserModel {
                    dispatchGroup.enter()
                    syncModelToFirebase(model: model) {
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        // 3. 删除对象
        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, !deletedObjects.isEmpty {
            for obj in deletedObjects {
                if let model = obj as? UserModel {
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
            
            // ✅ 延迟 2 秒后重置标志位（确保监听器不会处理自己的数据）
            // 这样即使监听器收到自己的数据，也会被跳过（因为 isLocalSyncing 为 true）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                // 重置本地同步标志位，允许监听器处理远程更新
                self.isLocalSyncingTimeoutWorkItem?.cancel()
                self.isLocalSyncing = false
                self.logInfo("✅ UserManger: 本地同步完成，已重置标志位，监听器恢复正常")
            }
        }
    }
    
    private func syncModelToFirebase(model: UserModel, completion: @escaping () -> Void) {
        // ✅ 简化：只使用 UUID 路径，每个设备只存储自己的用户信息
        let userUUID = model.id ?? currentUserUUID
        
        // ✅ 只同步自己的用户信息（不存储伴侣信息）
        guard userUUID == currentUserUUID else {
            logInfo("ℹ️ 跳过同步：只同步自己的用户信息（UUID：\(userUUID)）")
            completion()
            return
        }
        
        // ✅ 修复：始终使用 CoupleStatusManager 的 isUserLinked 值，确保连接状态正确同步
        // 这样可以防止因为 model.isInLinkedState 被错误设置而导致连接断开
        let currentIsLinked = CoupleStatusManager.shared.isUserLinked
        
        // 补充用户扩展信息（性别、出生年月、设备型号、链接状态、发起方标记、头像URL）
        var firestoreData: [String: Any] = [
            "id": userUUID,
            "userName": model.userName ?? "YourName",
            "userUUID": userUUID, // 存储用户UUID
            "8digitId": CoupleStatusManager.shared.ownInvitationCode ?? "", // 存储8位ID（兼容性）
            "partner8digitId": CoupleStatusManager.shared.partnerId ?? "", // 存储伴侣8位ID（兼容性）
            "gender": model.gender ?? "未知",
            "birthday": model.birthday ?? Date(),
            "deviceModel": model.deviceModel ?? UserModel.getCurrentDeviceModel(),
            "isInLinkedState": currentIsLinked, // ✅ 修复：始终使用 CoupleStatusManager 的值
            "isInitiator": model.isInitiator ?? CoupleStatusManager.isCurrentUserLinkInitiator(),
            "creationDate": model.creationDate ?? Date(),
            "serverTimestamp": FieldValue.serverTimestamp()
        ]
        
        // ✅ 同步头像 URL 到 Firebase
        if let avatarURL = model.avatarImageURL, !avatarURL.isEmpty {
            firestoreData["avatarImageURL"] = avatarURL
        }
        if let together = model.relationshipStartDate {
            firestoreData["relationshipStartDate"] = Timestamp(date: together)
        }
        
        DispatchQueue.global(qos: .utility).async {
            let db = Firestore.firestore()
            
            // ✅ 优化：简化路径，直接存储在 users/{UUID}（去掉 userInfo 子集合）
            db.collection("users")
                .document(userUUID)
                .setData(firestoreData, merge: true) { [weak self] error in
                    guard let self = self else {
                        DispatchQueue.main.async { completion() }
                        return
                    }
                    if let error = error {
                        self.logError("❌ 同步用户信息到 Firebase 失败(\(userUUID)):\(error.localizedDescription)")
                    } else {
                        self.logInfo("✅ 同步用户信息到 Firebase 成功（UUID：\(userUUID)）")
                        // ✅ 修改：只有在已链接伴侣时才更新 couples 表（引导页时可能还未链接）
                        // ✅ 这样引导页的数据只会保存到 users/{UUID}，不会影响 couples 集合
                        if CoupleStatusManager.shared.isUserLinked,
                           let coupleId = CoupleStatusManager.getPartnerId(),
                           !coupleId.isEmpty {
                            self.logInfo("✅ 用户已链接伴侣，更新 couples 表中的用户信息")
                            self.updateCoupleInfoInFirebase(userUUID: userUUID, userData: firestoreData, coupleId: coupleId)
                        } else {
                            self.logInfo("ℹ️ 用户未链接伴侣，跳过更新 couples 表（引导页阶段）")
                        }
                    }
                    DispatchQueue.main.async {
                        completion()
                    }
                }
        }
    }
    
    /// Core Data → Firebase 删除（带完成回调，按UUID删除）
    private func deleteModelFromFirebase(model: UserModel, completion: @escaping () -> Void) {
        // ✅ 简化：只使用 UUID 路径，每个设备只删除自己的用户信息
        let userUUID = model.id ?? currentUserUUID
        
        // ✅ 只删除自己的用户信息（不删除伴侣信息）
        guard userUUID == currentUserUUID else {
            logInfo("ℹ️ 跳过删除：只删除自己的用户信息（UUID：\(userUUID)）")
            completion()
            return
        }
        
        DispatchQueue.global(qos: .utility).async {
            let db = Firestore.firestore()
            
            // ✅ 优化：只从自己的 UUID 路径删除：users/{UUID}（简化路径，去掉 userInfo 子集合）
            db.collection("users")
                .document(userUUID)
                .delete { [weak self] error in
                    if let error = error {
                        self?.logError("❌ 从 Firebase 删除用户信息失败(\(userUUID)): \(error.localizedDescription)")
                    } else {
                        self?.logInfo("✅ 从 Firebase 删除用户信息成功（UUID：\(userUUID)）")
                    }
                    DispatchQueue.main.async {
                        completion()
                    }
                }
        }
    }
    
    // MARK: - 新增：配对后同步双方用户信息（按UUID区分）
    func syncCoupleUserInfoAfterLink(partner8DigitId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        
        // 1. 获取自己的用户信息
        guard let own8DigitId = CoupleStatusManager.shared.ownInvitationCode,
              let ownUserModel = getUserModelByUUID(currentUserUUID) else {
            completion(false)
            return
        }
        
        // 2. 查询伴侣的用户信息（通过8位ID获取伴侣UUID）
        dispatchGroup.enter()
        // ✅ 防护：确保第一个 enter 只 leave 一次，避免多调崩溃；超时后强制 leave，避免引导页链接成功后卡住
        var firstGroupDidLeave = false
        let firstGroupLeaveOnce: () -> Void = {
            guard !firstGroupDidLeave else { return }
            firstGroupDidLeave = true
            dispatchGroup.leave()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { firstGroupLeaveOnce() }
        
        db.collection("pending_invitations").document(partner8DigitId).getDocument { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot, snapshot.exists, error == nil else {
                firstGroupLeaveOnce()
                completion(false)
                return
            }
            
            let partnerUUID = snapshot.data()?["userUUID"] as? String ?? ""
            let partnerName = snapshot.data()?["userName"] as? String ?? "未知用户"
            let partnerDeviceModel = snapshot.data()?["deviceModel"] as? String ?? "未知设备"
            let partnerAvatarURL = snapshot.data()?["avatarImageURL"] as? String ?? ""
            
            logInfo("✅ UserManger: 从 pending_invitations 读取到对方信息")
            logInfo("  - UUID: \(partnerUUID)")
            logInfo("  - 名字: \(partnerName)")
            logInfo("  - 头像: \(partnerAvatarURL.isEmpty ? "无" : "有(长度:\(partnerAvatarURL.count))")")
            
            // ✅ 如果 pending_invitations 中没有头像，尝试从 users/{partnerUUID} 读取
            if partnerAvatarURL.isEmpty {
                logInfo("⚠️ UserManger: pending_invitations 中没有头像，尝试从 users/{partnerUUID} 读取")
                db.collection("users").document(partnerUUID).getDocument { [weak self] userSnapshot, userError in
                    guard let self = self else {
                        firstGroupLeaveOnce()
                        return
                    }
                    var finalAvatarURL = partnerAvatarURL
                    
                    if let userSnapshot = userSnapshot, userSnapshot.exists,
                       let userData = userSnapshot.data(),
                       let avatarURL = userData["avatarImageURL"] as? String, !avatarURL.isEmpty {
                        finalAvatarURL = avatarURL
                        logInfo("✅ UserManger: 从 users/{partnerUUID} 读取到头像")
                    } else {
                        logInfo("⚠️ UserManger: users/{partnerUUID} 中也没有头像")
                    }
                    
                    // 3. 将伴侣信息保存到本地CoreData（按UUID区分）
                    if self.getUserModelByUUID(partnerUUID) == nil {
                        let _ = self.addModel(
                            userName: partnerName,
                            userUUID: partnerUUID,
                            eightDigitId: partner8DigitId,
                            deviceModel: partnerDeviceModel,
                            avatarImageURL: finalAvatarURL,
                            isInLinkedState: true,
                            isInitiator: false // 伴侣不是当前链接发起方
                        )
                    } else {
                        // ✅ 如果已存在，更新头像和名字
                        if let existingModel = self.getUserModelByUUID(partnerUUID) {
                            existingModel.userName = partnerName
                            existingModel.avatarImageURL = finalAvatarURL
                            NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
                            self.saveContext()
                            self.loadContent()
                            logInfo("✅ UserManger: 已更新现有伴侣信息的头像和名字")
                        }
                    }
                    
                    // ✅ 修复：此分支也必须执行「写自己文档 + 创建 couples + leave」，否则 notify 永不触发，伴侣监听器不会启动，对方头像无法更新
                    let ownUserRef = db.collection("users").document(self.currentUserUUID)
                    var ownUserData: [String: Any] = [
                        "id": ownUserModel.id ?? self.currentUserUUID,
                        "userName": ownUserModel.userName ?? "YourName",
                        "userUUID": self.currentUserUUID,
                        "8digitId": own8DigitId,
                        "partner8digitId": partner8DigitId,
                        "gender": ownUserModel.gender ?? "未知",
                        "birthday": ownUserModel.birthday ?? Date(),
                        "deviceModel": ownUserModel.deviceModel ?? UserModel.getCurrentDeviceModel(),
                        "isInLinkedState": true,
                        "isInitiator": CoupleStatusManager.isCurrentUserLinkInitiator(),
                        "creationDate": ownUserModel.creationDate ?? Date(),
                        "serverTimestamp": FieldValue.serverTimestamp()
                    ]
                    if let avatarURL = ownUserModel.avatarImageURL, !avatarURL.isEmpty {
                        ownUserData["avatarImageURL"] = avatarURL
                    }
                    ownUserRef.setData(ownUserData, merge: true) { [weak self] _ in
                        guard let self = self else {
                            firstGroupLeaveOnce()
                            return
                        }
                        let finalCoupleId = min(own8DigitId, partner8DigitId)
                        let coupleRef = db.collection("couples").document(finalCoupleId)
                        let currentUUID = self.currentUserUUID
                        let isInitiator = CoupleStatusManager.isCurrentUserLinkInitiator()
                        var coupleData: [String: Any] = [
                            "coupleId": finalCoupleId,
                            "createdAt": FieldValue.serverTimestamp()
                        ]
                        if isInitiator {
                            coupleData["initiatorUserId"] = currentUUID
                            coupleData["partnerUserId"] = partnerUUID
                        } else {
                            coupleData["initiatorUserId"] = partnerUUID
                            coupleData["partnerUserId"] = currentUUID
                        }
                        coupleRef.setData(coupleData, merge: true) { [weak self] error in
                            if let error = error {
                                self?.logError("❌ UserManger: 创建/更新 couples 文档失败: \(error.localizedDescription)")
                            }
                            firstGroupLeaveOnce()
                        }
                    }
                }
            } else {
                // 3. 将伴侣信息保存到本地CoreData（按UUID区分）
                if self.getUserModelByUUID(partnerUUID) == nil {
                    let _ = self.addModel(
                        userName: partnerName,
                        userUUID: partnerUUID,
                        eightDigitId: partner8DigitId,
                        deviceModel: partnerDeviceModel,
                        avatarImageURL: partnerAvatarURL,
                        isInLinkedState: true,
                        isInitiator: false // 伴侣不是当前链接发起方
                    )
                } else {
                    // ✅ 如果已存在，更新头像和名字
                    if let existingModel = self.getUserModelByUUID(partnerUUID) {
                        existingModel.userName = partnerName
                        existingModel.avatarImageURL = partnerAvatarURL
                        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
                        self.saveContext()
                        self.loadContent()
                        self.logInfo("✅ UserManger: 已更新现有伴侣信息的头像和名字")
                    }
                }
            }
            
            // ✅ 修复：4. 将自己的信息同步到【自己的】Firebase 用户文档（users/当前用户UUID）
            // 错误做法：不要把自己的信息写入伴侣的文档，否则会导致对方头像/名字被覆盖成自己的一样
            let ownUserRef = db.collection("users")
                .document(self.currentUserUUID)
            
            var ownUserData: [String: Any] = [
                "id": ownUserModel.id ?? self.currentUserUUID,
                "userName": ownUserModel.userName ?? "YourName",
                "userUUID": self.currentUserUUID,
                "8digitId": own8DigitId,
                "partner8digitId": partner8DigitId,
                "gender": ownUserModel.gender ?? "未知",
                "birthday": ownUserModel.birthday ?? Date(),
                "deviceModel": ownUserModel.deviceModel ?? UserModel.getCurrentDeviceModel(),
                "isInLinkedState": true,
                "isInitiator": CoupleStatusManager.isCurrentUserLinkInitiator(),
                "creationDate": ownUserModel.creationDate ?? Date(),
                "serverTimestamp": FieldValue.serverTimestamp()
            ]
            
            // ✅ 添加头像URL（如果存在）
            if let avatarURL = ownUserModel.avatarImageURL, !avatarURL.isEmpty {
                ownUserData["avatarImageURL"] = avatarURL
                logInfo("✅ UserManger: 同步自己的头像到自己的 Firebase 用户文档")
            } else {
                logInfo("⚠️ UserManger: 自己的头像为空，无法同步到自己的 Firebase 用户文档")
            }
            
            ownUserRef.setData(ownUserData, merge: true) { [weak self] _ in
                guard let self = self else {
                    firstGroupLeaveOnce()
                    return
                }
                
                // ✅ 6. 创建或更新 couples 文档（存储 initiatorUserId 和 partnerUserId）
                // ✅ 注意：这里在闭包内，partnerUUID 在作用域内
                let finalCoupleId = min(own8DigitId, partner8DigitId)
                let coupleRef = db.collection("couples").document(finalCoupleId)
                
                // ✅ 判断当前用户是 initiator 还是 partner
                let currentUUID = self.currentUserUUID
                let isInitiator = CoupleStatusManager.isCurrentUserLinkInitiator()
                
                var coupleData: [String: Any] = [
                    "coupleId": finalCoupleId,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                
                if isInitiator {
                    coupleData["initiatorUserId"] = currentUUID
                    coupleData["partnerUserId"] = partnerUUID
                } else {
                    coupleData["initiatorUserId"] = partnerUUID
                    coupleData["partnerUserId"] = currentUUID
                }
                
                coupleRef.setData(coupleData, merge: true) { [weak self] error in
                    guard let self = self else {
                        firstGroupLeaveOnce()
                        return
                    }
                    if let error = error {
                        self.logError("❌ UserManger: 创建/更新 couples 文档失败: \(error.localizedDescription)")
                    } else {
                        self.logInfo("✅ UserManger: 成功创建/更新 couples 文档（coupleId: \(finalCoupleId), initiator: \(coupleData["initiatorUserId"] ?? "nil"), partner: \(coupleData["partnerUserId"] ?? "nil")）")
                    }
                    firstGroupLeaveOnce()
                }
            }
        }
        
        // ✅ 优化：5. 将伴侣信息同步到自己的Firebase用户文档（简化路径）
        // 注意：实际上每个用户只应该存储自己的信息，伴侣信息应该从 couples/{coupleId} 或 users/{partnerUUID} 获取
        // 这里保留是为了兼容，但建议将来移除
        dispatchGroup.enter()
        db.collection("pending_invitations").document(partner8DigitId).getDocument { [weak self] snapshot, error in
            guard let self = self, let snapshot = snapshot, snapshot.exists, error == nil else {
                dispatchGroup.leave()
                completion(false)
                return
            }
            
            let partnerUUID = snapshot.data()?["userUUID"] as? String ?? ""
            let partnerName = snapshot.data()?["userName"] as? String ?? "未知用户"
            let partnerDeviceModel = snapshot.data()?["deviceModel"] as? String ?? "未知设备"
            
            // ✅ 注意：这里不应该将伴侣信息存储到自己的用户文档中
            // 伴侣信息应该从 users/{partnerUUID} 或 couples/{coupleId}/partnerInfo 获取
            // 为了兼容，这里暂时保留，但不写入数据
            logInfo("ℹ️ UserManger: 跳过将伴侣信息存储到自己的用户文档（优化后的架构不需要）")
            dispatchGroup.leave()
        }
        
        // 7. 所有同步完成
        dispatchGroup.notify(queue: .main) {
            self.loadContent()
            // ✅ 新增：连接完成后，启动伴侣信息监听（实时同步对方的名字和头像）
            self.setupPartnerFirebaseListener()
            completion(true)
        }
    }
    
    // ✅ 防抖标志，避免频繁发送通知导致卡顿
    private var loadContentWorkItem: DispatchWorkItem?
    private var lastLoadContentTime: Date = Date.distantPast
    private var isNotificationPending = false // ✅ 标记是否有待发送的通知
    private let notificationDebounceInterval: TimeInterval = 0.5 // ✅ 防抖间隔：0.5秒
    /// 上次清空头像缓存时的头像签名；仅当当前头像与签名不一致时才清空，避免另一台设备同步时反复清空导致闪烁
    private var lastClearedAvatarSignature: String?
    
    // MARK: - 本地数据操作
    /// 重新加载本地用户数据并发出「数据已修改」通知。所有头像/用户信息展示处应只在此通知时做一次整体刷新。
    func loadContent() {
        models = UserModel.mr_findAllSorted(by: "creationDate", ascending: true) as? [UserModel] ?? []
        updatePipe.input.send(value: 1)
        
        // ✅ 如果已经有待发送的通知，取消之前的任务，重新计时
        loadContentWorkItem?.cancel()
        
        // ✅ 检查距离上次通知的时间
        let now = Date()
        let timeSinceLastNotification = now.timeIntervalSince(lastLoadContentTime)
        
        // ✅ 如果距离上次通知时间小于防抖间隔，延迟发送
        let delay: TimeInterval = timeSinceLastNotification < notificationDebounceInterval ? 
            notificationDebounceInterval - timeSinceLastNotification : 0
        
        // ✅ 标记有待发送的通知
        isNotificationPending = true
        
        // ✅ 创建新的通知任务
        loadContentWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // ✅ 再次检查是否应该发送（防止在延迟期间被多次调用）
            let currentTime = Date()
            let timeSinceLast = currentTime.timeIntervalSince(self.lastLoadContentTime)
            
            // ✅ 如果距离上次通知时间仍然小于防抖间隔，跳过
            guard timeSinceLast >= self.notificationDebounceInterval else {
                self.logDebug("ℹ️ UserManger: 跳过通知发送（距离上次通知仅 \(String(format: "%.2f", timeSinceLast)) 秒）")
                self.isNotificationPending = false
                return
            }
            
            // ✅ 仅当头像 URL 实际变化时才清空头像展示缓存，避免另一台设备同步时反复清空导致头像一直闪烁
            let couple = self.getCoupleNamesAndAvatars()
            let currentSignature = Self.avatarSignature(myAvatar: couple.myAvatar, partnerAvatar: couple.partnerAvatar)
            if currentSignature != self.lastClearedAvatarSignature {
                UserAvatarDisplayCache.shared.clear()
                ImageProcessor.shared.clearCutoutCache()
                self.lastClearedAvatarSignature = currentSignature
            }
            self.lastLoadContentTime = currentTime
            self.isNotificationPending = false
            NotificationCenter.default.post(name: UserManger.dataDidUpdateNotification, object: nil)
        }
        
        // ✅ 延迟执行通知任务
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: loadContentWorkItem!)
    }
    
    /// 生成头像签名，用于判断是否需要清空展示缓存（仅比较长度+前缀，避免存整段 base64）
    private static func avatarSignature(myAvatar: String, partnerAvatar: String) -> String {
        let a = myAvatar
        let b = partnerAvatar
        let p = 120
        return "\(a.count):\(String(a.prefix(p)))|\(b.count):\(String(b.prefix(p)))"
    }
    
    // 重载：支持传入更多用户扩展信息，按UUID创建用户
    func addModel(
        userName: String,
        userUUID: String? = nil,
        eightDigitId: String? = nil,
        gender: String? = nil,
        birthday: Date? = nil,
        deviceModel: String? = nil,
        avatarImageURL: String? = nil,
        isInLinkedState: Bool? = nil,
        isInitiator: Bool? = nil
    ) -> UserModel? {
        guard let model = UserModel.mr_createEntity() else { return nil }
        
        let finalUUID = userUUID ?? currentUserUUID
        model.id = finalUUID
        model.creationDate = Date()
        model.userName = userName
        
        // ✅ 优先从 UserDefaults 读取性别（如果存在），否则使用传入的 gender
        let finalGender = gender ?? CoupleStatusManager.shared.userGender
        model.gender = finalGender
        if let finalGender = finalGender {
            // ✅ 如果是当前用户，同时保存到 UserDefaults
            if finalUUID == currentUserUUID {
                CoupleStatusManager.shared.userGender = finalGender
            }
        }
        
        model.birthday = birthday
        model.deviceModel = deviceModel ?? UserModel.getCurrentDeviceModel()
        model.avatarImageURL = avatarImageURL
        model.isInLinkedState = isInLinkedState ?? CoupleStatusManager.shared.isUserLinked
        model.isInitiator = isInitiator ?? CoupleStatusManager.isCurrentUserLinkInitiator()
        
        logInfo("✅ CoreData新增用户，绑定UUID：\(finalUUID)")
        logInfo("  - 名字: \(userName)")
        logInfo("  - 性别: \(finalGender ?? "未设置")")
        logInfo("  - 头像: \(avatarImageURL?.isEmpty == false ? "有(长度:\(avatarImageURL?.count ?? 0))" : "无")")
        
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        
        // 同步到Firebase（按UUID同步）
        syncModelToFirebase(model: model) {}
        
        return model
    }
    
    // 新增：按UUID更新用户信息
    func updateUserByUUID(
        uuid: String,
        userName: String? = nil,
        gender: String? = nil,
        birthday: Date? = nil,
        isInLinkedState: Bool? = nil
    ) -> UserModel? {
        guard let model = getUserModelByUUID(uuid) else {
            logError("❌ 未找到UUID为\(uuid)的用户，无法更新")
            return nil
        }
        
        if let userName = userName {
            model.userName = userName
        }
        if let gender = gender {
            model.gender = gender
            // ✅ 同时保存到 UserDefaults
            CoupleStatusManager.shared.userGender = gender
            logInfo("✅ UserManger: 性别已保存到 CoreData 和 UserDefaults = \(gender)")
        }
        if let birthday = birthday {
            model.birthday = birthday
        }
        if let isInLinkedState = isInLinkedState {
            model.isInLinkedState = isInLinkedState
        } else {
            // ✅ 修复：如果没有传入 isInLinkedState，确保与 CoupleStatusManager 保持一致
            // 这样可以防止修改名字时错误地清除连接状态
            model.isInLinkedState = CoupleStatusManager.shared.isUserLinked
            logInfo("✅ UserManger: 自动同步 isInLinkedState = \(CoupleStatusManager.shared.isUserLinked)")
        }
        
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent() // ✅ loadContent() 内部会发送 UserManger.dataDidUpdateNotification 通知
        syncModelToFirebase(model: model) {}
        
        logInfo("✅ 已更新UUID为\(uuid)的用户信息")
        // ✅ 通知已通过 loadContent() 发送，UserAvatarViewController 会自动更新
        return model
    }
    
    /// 仅将当前用户的 isInLinkedState 同步到 Firebase（断开重连时发起方先写，对方设备能尽快看到「已链接」避免误判）
    func syncMyLinkStateToFirebase() {
        guard let model = getUserModelByUUID(currentUserUUID) else { return }
        model.isInLinkedState = CoupleStatusManager.shared.isUserLinked
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        syncModelToFirebase(model: model) {}
        logInfo("✅ UserManger: 已同步本机 isInLinkedState = \(CoupleStatusManager.shared.isUserLinked) 到 Firebase")
    }
    
    // ✅ 新增：更新用户头像 URL
    func updateAvatarURL(uuid: String, avatarURL: String) {
        guard let model = getUserModelByUUID(uuid) else {
            logError("❌ 未找到UUID为\(uuid)的用户，无法更新头像URL")
            return
        }
        
        model.avatarImageURL = avatarURL
        
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent() // ✅ loadContent() 内部会发送 UserManger.dataDidUpdateNotification 通知
        
        // ✅ 同步到 Firebase
        syncModelToFirebase(model: model) {}
        // ✅ 仅修改头像时发送，各页只在此通知时刷新头像，避免频繁刷新
        NotificationCenter.default.post(name: UserManger.avatarDidUpdateNotification, object: nil)
    }
    
    /// 引导页「在一起日期」，与生日分开存、同步到 users/{uuid}
    func updateRelationshipStartDate(uuid: String, date: Date) {
        guard let model = getUserModelByUUID(uuid) else {
            logError("❌ 未找到用户，无法更新在一起日期")
            return
        }
        model.relationshipStartDate = date
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        syncModelToFirebase(model: model) {}
        logInfo("✅ 已保存在一起日期并同步 Firebase")
    }
    
    func updateModel(_ model: UserModel) {
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        syncModelToFirebase(model: model) {}
    }
    
    func deleteModel(_ model: UserModel) {
        model.mr_deleteEntity()
        NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
        saveContext()
        loadContent()
        deleteModelFromFirebase(model: model) {}
    }
    
    func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
            logError("Failed to save context: \(error)")
        }
    }
    
    func fetchUserModels() -> [UserModel] {
        UserModel.mr_findAllSorted(by: "creationDate", ascending: false) as? [UserModel] ?? []
    }
    
    // 新增：通过UUID获取用户模型（精准查询）
    func getUserModelByUUID(_ uuid: String) -> UserModel? {
        let predicate = NSPredicate(format: "id == %@", uuid) // UserModel的id字段存储UUID
        return UserModel.mr_findFirst(with: predicate)
    }
    
    // 新增：获取配对双方用户（区分当前用户和伴侣，基于UUID）
    func getCoupleUsers() -> (currentUser: UserModel?, partnerUser: UserModel?) {
        // ✅ 移除 refreshAllObjects()，因为它可能导致崩溃
        // fetchUserModels() 会从数据库获取最新数据，不需要刷新所有对象
        
        let allUsers = fetchUserModels()
        let currentUUID = currentUserUUID
        
        // 1. 精准筛选：当前登录用户（严格匹配UUID）
        let currentUser = allUsers.first { $0.id == currentUUID }
        
        // 2. 精准筛选：伴侣用户（满足2个核心条件，双重校验）
        // ✔️ 条件1：ID 不等于自己的UUID
        // ✔️ 条件2：处于已配对状态（isInLinkedState = true）→ 排除冗余/未配对数据
        let partnerUser = allUsers.first { model in
            guard let modelId = model.id else { return false }
            return modelId != currentUUID && model.isInLinkedState == true
        }
        
        // ✅ 如果没找到伴侣用户，尝试从 Firebase couples 文档获取伴侣UUID，然后查找
        if partnerUser == nil, let coupleId = CoupleStatusManager.getPartnerId() {
            logInfo("⚠️ UserManger: 未在CoreData找到伴侣，尝试从Firebase获取")
            let db = Firestore.firestore()
            db.collection("couples").document(coupleId).getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let snapshot = snapshot, snapshot.exists, error == nil,
                      let data = snapshot.data() else {
                    self.logError("❌ UserManger: 从Firebase获取伴侣信息失败")
                    return
                }
                
                let initiatorUUID = data["initiatorUserId"] as? String ?? ""
                let partnerUserId = data["partnerUserId"] as? String ?? ""
                let actualPartnerUUID = (currentUUID == initiatorUUID) ? partnerUserId : initiatorUUID
                
                if !actualPartnerUUID.isEmpty && actualPartnerUUID != currentUUID {
                    self.logInfo("✅ UserManger: 从Firebase获取到伴侣UUID: \(actualPartnerUUID)")
                    // ✅ 如果CoreData中没有这个用户，尝试从Firebase同步
                    if self.getUserModelByUUID(actualPartnerUUID) == nil {
                        self.logInfo("⚠️ UserManger: CoreData中没有伴侣用户，需要从Firebase同步")
                        // 这里可以触发同步逻辑，但为了不阻塞当前调用，先返回nil
                    }
                }
            }
        }
        
        return (currentUser, partnerUser)
    }
    
    // ✅ 便捷方法：直接获取两个人的名称和头像（可在任何地方调用）
    struct CoupleInfo {
        var myName: String
        var myAvatar: String
        var partnerName: String
        var partnerAvatar: String
        var myUserModel: UserModel?
        var partnerUserModel: UserModel?
    }
    
    /// 获取配对双方的名称和头像信息
    /// - Returns: CoupleInfo 结构体，包含自己和伴侣的名称、头像URL
    /// - Note: 如果 CoreData 中没有伴侣信息，会自动尝试从 Firebase 同步
    func getCoupleNamesAndAvatars() -> CoupleInfo {
        let (currentUser, partnerUser) = getCoupleUsers()
        
        // 获取自己的信息
        let myName = currentUser?.userName ?? "未知"
        let myAvatar = currentUser?.avatarImageURL ?? ""
        
        // 获取伴侣的信息
        var partnerName = partnerUser?.userName ?? "未知"
        var partnerAvatar = partnerUser?.avatarImageURL ?? ""
        
        // ✅ 如果 CoreData 中没有伴侣信息或信息不完整，尝试从 Firebase 同步
        // ✅ 仅在已链接且有 coupleId 时才同步（重新链接/刚断链时无 coupleId，避免报错）
        let needSyncPartner = partnerUser == nil || partnerName == "未知" || partnerAvatar.isEmpty
        if needSyncPartner, CoupleStatusManager.shared.isUserLinked, CoupleStatusManager.getPartnerId() != nil {
            syncPartnerInfoFromFirebaseToCoreData(completion: nil)
        }
        
        return CoupleInfo(
            myName: myName,
            myAvatar: myAvatar,
            partnerName: partnerName,
            partnerAvatar: partnerAvatar,
            myUserModel: currentUser,
            partnerUserModel: partnerUser
        )
    }
    
    // ✅ 新增：从 Firebase 获取并保存伴侣信息（名字、头像等）到本地 CoreData
    func syncPartnerInfoFromFirebaseToCoreData(completion: ((Bool, UserModel?) -> Void)? = nil) {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            logError("❌ UserManger: 没有 coupleId，无法获取伴侣信息")
            completion?(false, nil)
            return
        }
        
        let currentUUID = currentUserUUID
        let db = Firestore.firestore()
        
        // ✅ 1. 从 couples 文档获取伴侣 UUID
        db.collection("couples").document(coupleId).getDocument { [weak self] snapshot, error in
            guard let self = self else {
                completion?(false, nil)
                return
            }
            
            if let error = error {
                self.logError("❌ UserManger: 从 Firebase couples 获取伴侣 UUID 失败 - 错误: \(error.localizedDescription)")
                completion?(false, nil)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists,
                  let data = snapshot.data() else {
                self.logError("❌ UserManger: couples 文档不存在或为空")
                completion?(false, nil)
                return
            }
            
            let initiatorUUID = data["initiatorUserId"] as? String ?? ""
            let partnerUserId = data["partnerUserId"] as? String ?? ""
            let partnerUUID = (currentUUID == initiatorUUID) ? partnerUserId : initiatorUUID
            
            guard !partnerUUID.isEmpty && partnerUUID != currentUUID else {
                completion?(false, nil)
                return
            }
            
            // ✅ 2. 从 Firebase 读取伴侣信息：users/{partnerUUID}
            db.collection("users")
                .document(partnerUUID)
                .getDocument { [weak self] partnerSnapshot, error in
                    guard let self = self else {
                        completion?(false, nil)
                        return
                    }
                    
                    if let error = error {
                        self.logError("❌ UserManger: 从 Firebase 读取伴侣信息失败 - 错误: \(error.localizedDescription)，路径: users/\(partnerUUID)")
                        completion?(false, nil)
                        return
                    }
                    
                    guard let partnerSnapshot = partnerSnapshot, partnerSnapshot.exists,
                          let partnerData = partnerSnapshot.data() else {
                        self.logError("❌ UserManger: 伴侣信息文档不存在或为空，路径: users/\(partnerUUID)")
                        completion?(false, nil)
                        return
                    }
                    
                    // ✅ 3. 确保 partnerData 中包含必要的字段（区分伴侣信息）
                    var finalPartnerData = partnerData
                    finalPartnerData["userUUID"] = partnerUUID // 确保 UUID 字段存在
                    finalPartnerData["isInLinkedState"] = true // ✅ 标记为已配对（用于区分伴侣）
                    
                    // ✅ 4. 同步到 CoreData（使用 syncItem 方法）
                    self.syncItem(documentID: partnerUUID, data: finalPartnerData) {
                        // ✅ 5. 同步完成后，从 CoreData 读取保存的模型
                        if let savedPartnerModel = self.getUserModelByUUID(partnerUUID) {
                            completion?(true, savedPartnerModel)
                        } else {
                            completion?(true, nil)
                        }
                    }
                }
        }
    }
    
    func syncItem(documentID: String, data: [String: Any], completion: (() -> Void)? = nil) {
        MagicalRecord.save({ (localContext) in
            // ✅ 防止「自己的头像被对方覆盖」：若更新的是当前用户记录，则 data 必须属于当前用户（userUUID 一致或为空）
            if documentID == self.currentUserUUID {
                let dataUUID = data["userUUID"] as? String
                if let uuid = dataUUID?.trimmingCharacters(in: .whitespaces), !uuid.isEmpty, uuid != self.currentUserUUID {
                    self.logError("❌ UserManger: 拒绝将伴侣数据写入当前用户记录，data.userUUID=\(uuid)，跳过同步")
                    return
                }
            }
            // ✅ 若更新的是伴侣记录，则 data 应属于伴侣（避免误把当前用户数据写进伴侣记录）
            if documentID != self.currentUserUUID {
                let dataUUID = data["userUUID"] as? String
                if let uuid = dataUUID?.trimmingCharacters(in: .whitespaces), !uuid.isEmpty, uuid == self.currentUserUUID {
                    self.logError("❌ UserManger: 拒绝将当前用户数据写入伴侣记录，documentID=\(documentID)，跳过同步")
                    return
                }
            }
            
            var targetModel: UserModel?
            // 按UUID查找已有模型
            if let existingModel = UserModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                targetModel = existingModel
            } else if let newModel = UserModel.mr_createEntity(in: localContext) {
                targetModel = newModel
                newModel.id = documentID
            }
            
            guard let model = targetModel else { return }
            
            // ✅ 保存本地已有的头像（如果存在），避免被 Firebase 空值覆盖
            let existingAvatarURL = model.avatarImageURL
            
            // 同步扩展信息（通过上方防护后，只更新当前这条记录，id 保持为 documentID 避免被 data 误改）
            model.id = documentID
            // ✅ 如果Firebase中的userName为空或"Name"或"YourName"，保存为空字符串（YourName只是显示占位符）
            if let firebaseUserName = data["userName"] as? String, !firebaseUserName.isEmpty, firebaseUserName != "Name", firebaseUserName != "YourName", firebaseUserName != "Your Name" {
                model.userName = firebaseUserName
            } else {
                // ✅ 如果userName为空或"Name"或"YourName"，保存为空字符串（YourName只是显示占位符）
                model.userName = ""
            }
            model.gender = data["gender"] as? String
            model.birthday = (data["birthday"] as? Timestamp)?.dateValue() ?? Date()
            model.deviceModel = data["deviceModel"] as? String
            
            // ✅ 修复：对于当前用户，始终使用 CoupleStatusManager 的真实连接状态
            // 对于伴侣用户，使用 Firebase 中的值（因为那是伴侣的状态）
            if documentID == self.currentUserUUID {
                // 当前用户：使用 CoupleStatusManager 的真实状态，防止被错误覆盖
                model.isInLinkedState = CoupleStatusManager.shared.isUserLinked
                model.isInitiator = CoupleStatusManager.isCurrentUserLinkInitiator()
            } else {
                // 伴侣用户：使用 Firebase 中的值
                model.isInLinkedState = data["isInLinkedState"] as? Bool ?? false
                model.isInitiator = data["isInitiator"] as? Bool ?? false
            }
            
            model.creationDate = (data["creationDate"] as? Timestamp)?.dateValue() ?? Date()
            if let relTs = data["relationshipStartDate"] as? Timestamp {
                model.relationshipStartDate = relTs.dateValue()
            }
            
            // ✅ 同步头像 URL：优先使用 Firebase 的头像（即使为空也更新，确保同步）
            let firebaseAvatarURL = data["avatarImageURL"] as? String
            if let firebaseAvatar = firebaseAvatarURL, !firebaseAvatar.isEmpty {
                model.avatarImageURL = firebaseAvatar
            } else {
                // Firebase 中头像为空时，保留本地头像（若有）；否则设为 nil
                if let existingAvatar = existingAvatarURL, !existingAvatar.isEmpty {
                    model.avatarImageURL = existingAvatar
                } else {
                    model.avatarImageURL = nil
                }
            }
        }, completion: { (success, error) in
            if success {
                self.loadContent()
                // ✅ 同步的是用户信息（含头像）时，通知 Home/Setting 等页面刷新头像显示；对方改头像后本机通过 Firebase 同步到这里，需发此通知否则停留在当前页不会更新
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: UserManger.avatarDidUpdateNotification, object: nil)
                }
            } else {
                let nsError = error as NSError?
                let isCriticalError = nsError?.code == 133020 || nsError?.code == 133021 || nsError?.code == 134040 ||
                    (nsError?.domain == "NSCocoaErrorDomain" && nsError?.code != 133000 && nsError?.code != 134030)
                if isCriticalError {
                    self.logError("❌ [UserManger] 同步Firebase用户数据到CoreData失败: \(error?.localizedDescription ?? "Unknown error")")
                } else {
                    // 非关键错误或未知错误：数据可能已保存，仍刷新
                    self.loadContent()
                }
            }
            // ✅ 调用 completion 回调
            completion?()
        })
    }
    
    func deleteItem(documentID: String) {
        MagicalRecord.save({ (localContext) in
            // 按UUID删除模型
            if let modelToDelete = UserModel.mr_findFirst(byAttribute: "id", withValue: documentID, in: localContext) {
                modelToDelete.mr_deleteEntity(in: localContext)
            }
        }, completion: { (success, error) in
            if success {
                // ✅ 刷新本地数据（确保 getCoupleUsers 能获取到最新数据）
                self.loadContent()
                self.logInfo("✅ 用户数据删除成功，已刷新本地数据并发送通知")
            } else {
                self.logError("❌ 删除CoreData用户模型失败: \(error?.localizedDescription ?? "Unknown error")")
            }
        })
    }
    
    // ✅ 新增：更新 couples 表中的用户信息（当用户更新名字或头像时，同步更新 couples 表）
    // ✅ 修改：接受 coupleId 参数，避免重复获取
    private func updateCoupleInfoInFirebase(userUUID: String, userData: [String: Any], coupleId: String) {
        let db = Firestore.firestore()
        let coupleRef = db.collection("couples").document(coupleId)
        
        // 获取当前用户信息
        let userName = userData["userName"] as? String ?? ""
        let avatarImageURL = userData["avatarImageURL"] as? String ?? ""
        let deviceModel = userData["deviceModel"] as? String ?? ""
        
        // 先获取当前的 couple 文档，判断当前用户是 initiator 还是 partner
        coupleRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            guard let snapshot = snapshot, snapshot.exists, error == nil,
                  let data = snapshot.data() else {
                self.logError("❌ UserManger: 获取 couple 文档失败：\(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let initiatorUUID = data["initiatorUserId"] as? String ?? ""
            let partnerUserId = data["partnerUserId"] as? String ?? ""
            let currentUUID = self.currentUserUUID
            
            // 判断当前用户是 initiator 还是 partner
            var updateData: [String: Any] = [:]
            if currentUUID == initiatorUUID {
                // 当前用户是 initiator，更新 initiatorInfo
                updateData["initiatorInfo"] = [
                    "userUUID": currentUUID,
                    "userName": userName,
                    "avatarImageURL": avatarImageURL,
                    "deviceModel": deviceModel
                ]
                self.logInfo("✅ UserManger: 更新 couples 表的 initiatorInfo（UUID：\(currentUUID)）")
            } else if currentUUID == partnerUserId {
                // 当前用户是 partner，更新 partnerInfo
                updateData["partnerInfo"] = [
                    "userUUID": currentUUID,
                    "userName": userName,
                    "avatarImageURL": avatarImageURL,
                    "deviceModel": deviceModel
                ]
                self.logInfo("✅ UserManger: 更新 couples 表的 partnerInfo（UUID：\(currentUUID)）")
            } else {
                self.logInfo("⚠️ UserManger: 当前用户UUID不在 couple 中，跳过更新")
                return
            }
            
            // 更新 couples 表
            coupleRef.updateData(updateData) { error in
                if let error = error {
                    self.logError("❌ UserManger: 更新 couples 表失败：\(error.localizedDescription)")
                } else {
                    self.logInfo("✅ UserManger: 已更新 couples 表，对方的设备会收到更新通知")
                }
            }
        }
    }
    
    // 新增：自动创建UUID关联的用户记录（包含设备型号等信息）
    private func autoCreateUUIDUserRecord() {
        // 查询是否已有当前UUID的用户记录
        let predicate = NSPredicate(format: "id == %@", currentUserUUID)
        let existingModels = UserModel.mr_findAll(with: predicate) as? [UserModel] ?? []
        
        if existingModels.isEmpty {
            // 若无记录，创建默认用户（包含设备型号、链接状态）
            // ✅ 创建时用户名为空字符串，不保存"YourName"（YourName只是显示占位符）
            let _ = addModel(
                userName: "",
                userUUID: currentUserUUID,
                deviceModel: UserModel.getCurrentDeviceModel(),
                isInLinkedState: CoupleStatusManager.shared.isUserLinked,
                isInitiator: CoupleStatusManager.isCurrentUserLinkInitiator()
            )
            logInfo("✅ 自动创建UUID关联用户记录，UUID：\(currentUserUUID)")
        } else {
            // ✅ 检查并修复：如果用户名为"Name"或"YourName"，清空为""（YourName只是显示占位符）
            if let existingModel = existingModels.first {
                let currentUserName = existingModel.userName ?? ""
                if currentUserName == "Name" || currentUserName == "YourName" || currentUserName == "Your Name" {
                    existingModel.userName = ""
                    NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
                    saveContext()
                    loadContent()
                    syncModelToFirebase(model: existingModel) {}
                    logInfo("✅ 已修复用户名称：从 '\(currentUserName)' 清空为 ''（YourName只是显示占位符）")
                }
            }
            logInfo("✅ 已存在UUID关联用户记录，UUID：\(currentUserUUID)")
        }
    }
}

extension UserModel {
    // 获取当前设备型号
    static func getCurrentDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
