//
//  CoupleStatusManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation

class CoupleStatusManager: NSObject {
    // MARK: - Singleton
    static let shared = CoupleStatusManager()
    private override init() {
        super.init()
        // ✅ 启动时监听断开链接通知，重新启动全局监听器
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleDidUnlink),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
        
        // ✅ 如果应用启动时已经链接，启动 couples 文档监听器
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if self.isUserLinked, let coupleId = self.partnerId {
                self.startCoupleDocumentListener(coupleId: coupleId)
                print("✅ CoupleStatusManager: 应用启动时检测到已链接，启动 couples 文档监听器")
            }
        }
    }
    
    // MARK: - 全局链接监听器
    private var globalLinkListener: ListenerRegistration?
    /// 正在用 getDocument(server) 确认被链接，避免重复处理
    private var isConfirmingIncomingLink = false
    // ✅ 新增：监听 couples 文档删除（检测断开链接）
    private var coupleDocumentListener: ListenerRegistration?
    // ✅ 新增：记录 couples 文档是否曾经存在（用于检测删除）
    private var wasCoupleDocumentExisting: Bool = false
    
    // MARK: - User Defaults Keys
    private enum Keys: String {
        case isUserLinked
        case partnerId
        case ownInvitationCode // 8位数字ID
        case hasLaunchedOnce   // 是否首次启动（只在引导页完成时设置）
        case isLinkInitiator   // 是否是链接发起方
        case userGender        // 用户性别
        case notificationAgreed // 用户是否同意发送通知（仅用户意愿，非系统权限）
    }
    
    // MARK: - 新增：用户唯一UUID（永久不变，启动时自动获取）
    var userUniqueUUID: String {
        return UserDefaults.getUserUniqueUUID()
    }
    
    // MARK: - 新增：是否是链接发起方
    var isLinkInitiator: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.isLinkInitiator.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.isLinkInitiator.rawValue) }
    }
    
    // MARK: - Public Properties（原有属性不变）
    var isUserLinked: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.isUserLinked.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.isUserLinked.rawValue) }
    }
    
    var partnerId: String? {
        get { UserDefaults.standard.string(forKey: Keys.partnerId.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.partnerId.rawValue) }
    }
    
    var ownInvitationCode: String? {
        get { UserDefaults.standard.string(forKey: Keys.ownInvitationCode.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.ownInvitationCode.rawValue) }
    }
    
    // MARK: - 新增：用户性别（保存到 UserDefaults）
    var userGender: String? {
        get { UserDefaults.standard.string(forKey: Keys.userGender.rawValue) }
        set {
            if let gender = newValue {
                UserDefaults.standard.set(gender, forKey: Keys.userGender.rawValue)
                UserDefaults.standard.synchronize()
                print("✅ CoupleStatusManager: 性别已保存到 UserDefaults = \(gender)")
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.userGender.rawValue)
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    // MARK: - 新增：用户通知同意意愿（保存到 UserDefaults，仅表示用户意愿，非系统权限）
    var notificationAgreed: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.notificationAgreed.rawValue) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.notificationAgreed.rawValue)
            UserDefaults.standard.synchronize()
            print("✅ CoupleStatusManager: 通知同意意愿已保存到 UserDefaults = \(newValue)")
        }
    }
    
    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: Keys.hasLaunchedOnce.rawValue)
    }
    
    // MARK: - 断开链接通知
    static let coupleDidUnlinkNotification = NSNotification.Name(rawValue: "CoupleDidUnlinkNotification")
    
    /// 本机是否正在走「主动点 Unlink」流程。为 true 时不弹「被对方断开」页；被动监听到对端 isInLinkedState=false 时为 false，可推引导页。
    var unlinkInitiatedByCurrentUser: Bool = false
    
    /// 本次链接成功的时间点；用于「链接后宽限时间」内忽略伴侣 isInLinkedState=false 的误判（引导页先设头像再链接时对方可能尚未同步）
    private var linkedSince: Date?
    
    /// 是否处于「链接后宽限时间」内（默认 15 秒）。宽限内不因伴侣 isInLinkedState=false 弹「被断开」页。
    func isWithinLinkGracePeriod(seconds: TimeInterval = 15) -> Bool {
        guard let since = linkedSince else { return false }
        return Date().timeIntervalSince(since) < seconds
    }
    
    // MARK: - 重置状态（原有逻辑不变，新增清除链接发起方标记）
    func resetAllStatus() {
        isUserLinked = false
        partnerId = nil
        linkedSince = nil
        // ✅ 不断除 ownInvitationCode，保留邀请码以便重新链接
        // ownInvitationCode = nil
        isLinkInitiator = false
        
        // ✅ 停止 couples 文档监听器
        stopCoupleDocumentListener()
        
        // ✅ 发送断开链接通知（handleCoupleDidUnlink 会延迟启动全局监听器）
        NotificationCenter.default.post(name: CoupleStatusManager.coupleDidUnlinkNotification, object: nil)
        print("✅ CoupleStatusManager: 已发送断开链接通知，邀请码保留: \(ownInvitationCode ?? "nil")")
    }
    
    // MARK: - 处理断开链接通知
    @objc private func handleCoupleDidUnlink() {
        print("🔔 CoupleStatusManager: 收到断开链接通知，延迟启动全局监听器")
        // ✅ 延迟 0.4 秒，避免 Firebase 缓存未更新时误判「被链接」自动重新链接
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.startGlobalLinkListener()
        }
    }
    
    static func getPartnerId() -> String? {
        return shared.partnerId
    }
    
    // 新增：对外暴露获取用户UUID的方法
    static func getUserUniqueUUID() -> String {
        return shared.userUniqueUUID
    }
    
    // 新增：对外暴露是否是链接发起方的方法
    static func isCurrentUserLinkInitiator() -> Bool {
        return shared.isLinkInitiator
    }
    
    func resetStatus() {
        resetAllStatus()
    }
    
    func setLinked(partnerId partnerCode: String, isInitiator: Bool) {
        // 1. 获取自己的邀请码
        guard let ownCode = self.ownInvitationCode else {
            // ✅ 修复：如果已链接，不应该清除状态（避免错误断开连接）
            if self.isUserLinked {
                AlertManager.showSingleButtonAlert(
                    message: "⚠️ 邀请码缺失，但检测到已存在的连接。请重新启动应用或联系支持。",
                    target: self
                )
                print("⚠️ CoupleStatusManager: 邀请码缺失，但已存在连接，不清除状态")
                return
            }
            // 只有在未链接状态下才显示错误（不清除状态，因为可能没有状态可清除）
            AlertManager.showSingleButtonAlert(
                message: "❌ Unable to set link status: Invitation code missing.",
                target: self
            )
            print("⚠️ CoupleStatusManager: 邀请码缺失，无法设置链接状态")
            return
        }
        let finalCoupleId = min(ownCode, partnerCode)
        
        self.isUserLinked = true
        self.isLinkInitiator = isInitiator // 标记是否是发起方
        // 3. 将标准化后的 Couple ID 存储到 partnerId 字段中
        self.partnerId = finalCoupleId
        self.linkedSince = Date() // ✅ 记录链接时间，用于宽限时间内忽略「被断开」误判
        
        // ✅ 确保 partnerId 已保存到 UserDefaults
        UserDefaults.standard.synchronize()
        
        print("✅ CoupleStatusManager: 设置链接状态完成")
        print("  - partnerId (coupleId): \(finalCoupleId)")
        print("  - isInitiator: \(isInitiator)")
        print("  - isUserLinked: \(self.isUserLinked)")
        
        // ✅ 链接成功后，停止全局监听器
        stopGlobalLinkListener()
        
        // ✅ 启动监听 couples 文档删除（检测断开链接）
        startCoupleDocumentListener(coupleId: finalCoupleId)
        
        // 同步链接发起方状态到Firebase
        syncLinkInitiatorStatusToFirebase(isInitiator: isInitiator, coupleId: finalCoupleId)
        
        // ✅ 修复时序问题：不在这里立即发送通知
        // ✅ 通知应该由调用者在 syncCoupleUserInfoAfterLink() 完成后再发送
        // ✅ 这样可以确保用户信息（头像、名称）同步完成后再启动各个Manager的监听器
        print("✅ CoupleStatusManager: 设置链接状态完成，等待用户信息同步后再发送通知")
    }
    
    // 新增：同步链接发起方状态到Firebase
    private func syncLinkInitiatorStatusToFirebase(isInitiator: Bool, coupleId: String) {
        let db = Firestore.firestore()
        db.collection("couples")
            .document(coupleId)
            .collection("linkInfo")
            .document(self.userUniqueUUID)
            .setData([
                "userId": self.userUniqueUUID,
                "isInitiator": isInitiator,
                "linkTime": FieldValue.serverTimestamp()
            ], merge: true) { error in
                if let error = error {
                    print("❌ 同步链接发起方状态失败: \(error.localizedDescription)")
                } else {
                    print("✅ 同步链接发起方状态成功，UUID: \(self.userUniqueUUID), 是否发起方: \(isInitiator)")
                }
            }
    }
    
    private func generateRandomInvitationCode() -> String {
        let min: UInt32 = 10000000
        let max: UInt32 = 99999999
        let randomNumber = min + arc4random_uniform(max - min + 1)
        return String(randomNumber)
    }
    
    // MARK: - ID唯一性校验
    private func checkInvitationCodeUniqueness(_ code: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let invitationRef = db.collection("pending_invitations").document(code)
        
        invitationRef.getDocument { (documentSnapshot, error) in
            if let error = error {
                print("⚠️ Error checking code uniqueness: \(error.localizedDescription)")
                // ✅ 修复：网络错误时，假设代码是唯一的（允许使用），避免无限重试
                // 如果代码真的被占用，上传时会失败，那时再处理
                print("ℹ️ 网络错误，假设代码 \(code) 是唯一的，继续使用")
                completion(true)
                return
            }
            // 如果文档不存在 (documentSnapshot?.exists == false)，则 code 是唯一的
            completion(documentSnapshot?.exists == false)
        }
    }
    
    private func uploadInvitationToFirestore(code: String, completion: @escaping (Bool) -> Void) {
        // ❗ Document ID (code) 已经是邀请码本身
        let db = Firestore.firestore()
        let invitationRef = db.collection("pending_invitations").document(code)
        
        // ✅ 获取当前用户信息（从 CoreData）
        let currentUUID = self.userUniqueUUID
        let (currentUser, _) = UserManger.manager.getCoupleUsers()
        let userName = currentUser?.userName ?? "Waves"
        let avatarImageURL = currentUser?.avatarImageURL ?? ""
        
        // ✅ 永久8位ID：不再写入 expireAt（避免TTL删除），长期保留 code -> userUUID 映射
        var invitationData: [String: Any] = [
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "userUUID": currentUUID, // 关联用户UUID，标记该8位码所属用户
            "userName": userName,
            "deviceModel": UserModel.getCurrentDeviceModel()
        ]
        
        // ✅ 如果有头像，也存储
        if !avatarImageURL.isEmpty {
            invitationData["avatarImageURL"] = avatarImageURL
        }
        
        invitationRef.setData(invitationData, merge: true) { error in
            if let error = error {
                print("❌ Error uploading invitation: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Invitation uploaded successfully with code: \(code)")
                self.ownInvitationCode = code
                completion(true)
            }
        }
    }
    
    private func isValid8DigitInvitationCode(_ code: String) -> Bool {
        return code.count == 8 && code.allSatisfy({ $0.isNumber })
    }
    
    // MARK: - ✅ 永久8位ID（对外暴露方法）
    /// 规则：每个用户/设备只持有一个永久8位ID；不再5分钟过期、不再自动重生、不再删除映射。
    func generateFirstLaunchId(completion: @escaping (String?) -> Void) {
        ensurePermanentInvitationCode(completion: completion)
    }
    
    /// 确保本地有一个永久8位ID；并尽量保证 Firestore `pending_invitations/{code}` 指向自己。
    func ensurePermanentInvitationCode(completion: @escaping (String?) -> Void) {
        let currentUUID = self.userUniqueUUID
        
        // 1) 本地已有8位ID：立即返回显示，后台校验/同步 Firebase
        if let existingCode = self.ownInvitationCode, isValid8DigitInvitationCode(existingCode) {
            completion(existingCode)
            
            let db = Firestore.firestore()
            let invitationRef = db.collection("pending_invitations").document(existingCode)
            invitationRef.getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("⚠️ CoupleStatusManager: 校验邀请码映射失败: \(error.localizedDescription)")
                    return
                }
                if let snapshot = snapshot, snapshot.exists {
                    let mappedUUID = snapshot.data()?["userUUID"] as? String ?? ""
                    if mappedUUID.isEmpty || mappedUUID == currentUUID {
                        self.uploadInvitationToFirestore(code: existingCode) { _ in }
                    } else {
                        print("⚠️ CoupleStatusManager: 本地邀请码 \(existingCode) 与他人冲突，重新生成")
                        self.generateAndUploadUniqueInvitationCode(completion: { newCode in
                            DispatchQueue.main.async { completion(newCode) }
                        })
                    }
                } else {
                    self.uploadInvitationToFirestore(code: existingCode) { _ in }
                }
            }
            return
        }
        
        // 2) 本地没有：先生成并立即返回（UI 立刻显示），再在后台上传 Firebase
        generateAndUploadUniqueInvitationCode(completion: completion)
    }
    
    /// 先生成 8 位 ID 并立即回调（避免界面一直显示 00000000），再在后台校验唯一性并上传 Firebase
    func generateAndUploadUniqueInvitationCode(completion: @escaping (String?) -> Void) {
        var newCode = generateRandomInvitationCode()
        var attempts = 0
        let maxAttempts = 10
        
        func attemptGeneration() {
            attempts += 1
            if attempts > maxAttempts {
                print("❌ Failed to generate a unique code after \(maxAttempts) attempts.")
                self.ownInvitationCode = newCode
                UserDefaults.standard.synchronize()
                completion(newCode)
                return
            }
            
            // ✅ 关键：先生成并立即保存、回调，UI 立刻显示真实 8 位 ID（不再等网络）
            self.ownInvitationCode = newCode
            UserDefaults.standard.synchronize()
            completion(newCode)
            
            // ✅ 后台：校验唯一性并上传 Firebase
            checkInvitationCodeUniqueness(newCode) { [weak self] isUnique in
                guard let self = self else { return }
                if isUnique {
                    self.uploadInvitationToFirestore(code: newCode) { success in
                        if success {
                            print("✅ 8位ID已上传 Firebase: \(newCode)")
                        } else {
                            print("⚠️ 8位ID上传失败（本地已保存）: \(newCode)")
                        }
                    }
                } else {
                    print("⚠️ Code \(newCode) 已被占用，重新生成...")
                    newCode = self.generateRandomInvitationCode()
                    attemptGeneration()
                }
            }
        }
        
        attemptGeneration()
    }
    
    // MARK: - 全局链接监听器管理
    /// 启动全局链接监听器（用于检测重新链接）
    func startGlobalLinkListener() {
        // ✅ 如果已链接，不需要监听
        guard !isUserLinked else {
            stopGlobalLinkListener()
            return
        }
        
        // ✅ 如果没有邀请码，无法监听
        guard let ownCode = ownInvitationCode, ownCode.count == 8 else {
            print("⚠️ CoupleStatusManager: 没有邀请码，无法启动全局监听器")
            return
        }
        
        // ✅ 防止重复启动监听器
        guard globalLinkListener == nil else {
            print("ℹ️ CoupleStatusManager: 全局链接监听器已存在，跳过重复启动")
            return
        }
        
        let db = Firestore.firestore()
        print("✅ CoupleStatusManager: 启动全局链接监听器，监听 linked_couples/\(ownCode)")
        
        globalLinkListener = db.collection("linked_couples").document(ownCode).addSnapshotListener { [weak self] (documentSnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ CoupleStatusManager: 全局链接监听器错误: \(error.localizedDescription)")
                return
            }
            
            guard let document = documentSnapshot else { return }
            // ✅ 只处理服务端数据，避免断开后缓存仍带旧文档导致误判「被链接」自动重新链接
            if document.metadata.isFromCache { return }
            guard document.exists, let partnerIdFromSnapshot = document.data()?["partnerId"] as? String, !partnerIdFromSnapshot.isEmpty else { return }
            if self.isUserLinked { return }
            if self.isConfirmingIncomingLink { return }
            
            self.isConfirmingIncomingLink = true
            // ✅ 断开重连时用服务端数据再确认一次，避免只收到缓存导致「对方连上了、我这边没连上」
            let ref = db.collection("linked_couples").document(ownCode)
            ref.getDocument(source: .server) { [weak self] serverSnapshot, serverError in
                guard let self = self else { return }
                self.isConfirmingIncomingLink = false
                if serverError != nil {
                    print("⚠️ CoupleStatusManager: 全局监听器 getDocument(server) 失败，跳过本次: \(serverError!.localizedDescription)")
                    return
                }
                guard let snap = serverSnapshot, snap.exists, let partnerId = snap.data()?["partnerId"] as? String, !partnerId.isEmpty else { return }
                if self.isUserLinked { return }
                
                print("🎉 CoupleStatusManager: 全局监听器经服务端确认被链接！partnerId: \(partnerId)")
                self.stopGlobalLinkListener()
                
                let isInitiator = false
                self.setLinked(partnerId: partnerId, isInitiator: isInitiator)
                UserDefaults.standard.set(true, forKey: "isCoupleLinked")
                UserDefaults.standard.synchronize()
                
                UserManger.manager.syncCoupleUserInfoAfterLink(partner8DigitId: partnerId) { success in
                    if success {
                        print("✅ CoupleStatusManager: 全局监听器检测到链接并同步用户信息成功")
                    } else {
                        print("⚠️ CoupleStatusManager: 全局监听器检测到链接但同步用户信息失败")
                    }
                    NotificationCenter.default.post(name: NSNotification.Name("CoupleDidLinkNotification"), object: nil)
                    DispatchQueue.main.async {
                        guard let topVC = UIViewController.getCurrentViewController(base: nil) else { return }
                        if let cheekVC = topVC as? CheekBootPageView {
                            print("✅ CoupleStatusManager: 对方在链接页，dismiss CheekBootPageView")
                            UnlinkConfirmPopup.forceRemoveFromAllWindows()
                            (cheekVC.navigationController ?? cheekVC).dismiss(animated: true) {
                                print("✅ CoupleStatusManager: CheekBootPageView 已关闭，功能已恢复")
                            }
                            return
                        }
                        print("✅ CoupleStatusManager: 链接成功！已与伴侣重新建立连接。")
                    }
                }
            }
        }
    }
    
    /// 停止全局链接监听器
    func stopGlobalLinkListener() {
        globalLinkListener?.remove()
        globalLinkListener = nil
        print("✅ CoupleStatusManager: 全局链接监听器已停止")
    }
    
    // MARK: - ✅ 新增：监听 couples 文档删除（检测断开链接）
    /// 启动监听 couples 文档删除
    private func startCoupleDocumentListener(coupleId: String) {
        // ✅ 先停止旧的监听器
        stopCoupleDocumentListener()
        
        // ✅ 如果未链接，不需要监听
        guard isUserLinked else {
            return
        }
        
        let db = Firestore.firestore()
        print("✅ CoupleStatusManager: 启动 couples 文档删除监听器，监听 couples/\(coupleId)")
        
        // ✅ 重置文档存在状态
        wasCoupleDocumentExisting = false
        
        coupleDocumentListener = db.collection("couples").document(coupleId).addSnapshotListener { [weak self] (documentSnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ CoupleStatusManager: couples 文档监听器错误: \(error.localizedDescription)")
                return
            }
            
            guard let document = documentSnapshot else { return }
            
            // ✅ 第一次回调：记录文档是否存在
            if !self.wasCoupleDocumentExisting && document.exists {
                self.wasCoupleDocumentExisting = true
                print("✅ CoupleStatusManager: couples/\(coupleId) 文档存在，开始监听删除")
                return
            }
            
            // ✅ 检测到文档被删除（之前存在，现在不存在，且当前状态是已链接）
            if self.wasCoupleDocumentExisting && !document.exists && self.isUserLinked {
                print("⚠️ CoupleStatusManager: 检测到 couples/\(coupleId) 文档被删除，伴侣已断开链接")
                
                self.stopCoupleDocumentListener()
                self.wasCoupleDocumentExisting = false
                self.resetAllStatus()
            }
            
            
        }
    }
    
    /// 停止监听 couples 文档删除
    private func stopCoupleDocumentListener() {
        coupleDocumentListener?.remove()
        coupleDocumentListener = nil
        wasCoupleDocumentExisting = false
        print("✅ CoupleStatusManager: couples 文档监听器已停止")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopGlobalLinkListener()
        stopCoupleDocumentListener()
    }
}


