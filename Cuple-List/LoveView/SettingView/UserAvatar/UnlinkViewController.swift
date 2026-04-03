//
//  UnlinkViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit
import CoreData
import MagicalRecord

class UnlinkViewController: UIViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUnlinkAvatars()
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = true
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = true
                tabBarController.homeAddButton?.isHidden = true
            }
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = false
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = false
                tabBarController.homeAddButton?.isHidden = false
            }
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
    }
    
    var backButton: UIButton!
    var titleLabel: UILabel!
    var leftAvatarImageView: UIImageView!   // 自己头像（左，永远在左）
    var rightAvatarImageView: UIImageView!  // 伴侣头像（右）
    var leftAvatarBackgroundView: UIImageView!   // 左侧背景（根据自己性别：maleblueback/femalepinkback）
    var rightAvatarBackgroundView: UIImageView! // 右侧背景（根据伴侣性别：maleblueback/femalepinkback）
    var middleUserBreakIamge: UIImageView! // 中间爱心（根据双方性别组合）
    var leftNameLabel: UILabel!   // 左侧自己名字
    var rightNameLabel: UILabel!  // 右侧伴侣名字
    var middleLabel: UILabel!
    var bottomMiddleLabel: UILabel!
    var continueButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUI()
    }
    
    func setUI() {
        view.backgroundColor = .white
        let backView = ViewGradientView()
        view.addSubview(backView)
        
        backView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backButton = UIButton()
        backButton.setImage(UIImage(named: "breakback"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        titleLabel = UILabel()
        titleLabel.text = "Unlink"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#322D3A")
        view.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        
        // 容器：左侧（自己+背景+名字）| 中间爱心 | 右侧（伴侣+背景+名字）
        let unlinkContainerView = UIView()
        view.addSubview(unlinkContainerView)
        let xxx68 = view.height() * 68.0 / 812.0
        unlinkContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(xxx68)
            make.height.equalToSuperview().multipliedBy(120.0 / 812.0)
            make.width.equalToSuperview().multipliedBy(249.0 / 375.0)
        }
        
//         左侧：自己头像 + 背景（根据自己性别 maleblueback/femalepinkback）
        let leftContainerView = UIView()
        leftContainerView.clipsToBounds = true
        leftContainerView.layer.cornerRadius = 18
        unlinkContainerView.addSubview(leftContainerView)
        
        leftContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(7)
            make.width.equalTo(69)
            make.height.equalTo(89)
        }
        
        leftAvatarBackgroundView = UIImageView()
        leftAvatarBackgroundView.contentMode = .scaleAspectFill
        leftAvatarBackgroundView.clipsToBounds = true
        leftAvatarBackgroundView.layer.cornerRadius = 18
        leftContainerView.addSubview(leftAvatarBackgroundView)
        leftAvatarBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
       
        leftAvatarImageView = UIImageView()
        leftAvatarImageView.contentMode = .scaleAspectFill
        leftAvatarImageView.clipsToBounds = true
        leftContainerView.addSubview(leftAvatarImageView)
        leftAvatarImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(69)
            make.height.equalTo(89)
        }
        
        
        // 左侧名字（自己）
        leftNameLabel = UILabel()
        leftNameLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        leftNameLabel.textColor = .color(hexString: "#322D3A")
        leftNameLabel.textAlignment = .center
        unlinkContainerView.addSubview(leftNameLabel)
        leftNameLabel.snp.makeConstraints { make in
            make.centerX.equalTo(leftContainerView)
            make.top.equalTo(leftContainerView.snp.bottom).offset(6)
        }
     
        
        // 中间爱心（根据双方性别：unlinkleftmale/unlinkmale/unlinkleftfemale/unlinkfemale）
        middleUserBreakIamge = UIImageView()
        middleUserBreakIamge.contentMode = .scaleAspectFit
        unlinkContainerView.addSubview(middleUserBreakIamge)
        middleUserBreakIamge.snp.makeConstraints { make in
            make.left.equalTo(leftContainerView.snp.right).offset(23)
            make.top.equalToSuperview()
            make.width.equalTo(67)
            make.height.equalTo(54)
        }
        
        // 右侧：伴侣头像 + 背景（根据伴侣性别 maleblueback/femalepinkback）
        let rightContainerView = UIView()
        rightContainerView.clipsToBounds = true
        rightContainerView.layer.cornerRadius = 18
        unlinkContainerView.addSubview(rightContainerView)
        
        rightContainerView.snp.makeConstraints { make in
            make.left.equalTo(middleUserBreakIamge.snp.right).offset(23)
            make.right.equalToSuperview()
            make.top.equalTo(7)
            make.width.equalTo(69)
            make.height.equalTo(89)
        }
        
        
        rightAvatarBackgroundView = UIImageView()
        rightAvatarBackgroundView.contentMode = .scaleAspectFill
        rightAvatarBackgroundView.clipsToBounds = true
        rightAvatarBackgroundView.layer.cornerRadius = 18
        rightContainerView.addSubview(rightAvatarBackgroundView)
        rightAvatarBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        rightAvatarImageView = UIImageView()
        rightAvatarImageView.contentMode = .scaleAspectFill
        rightAvatarImageView.clipsToBounds = true
        rightContainerView.addSubview(rightAvatarImageView)
        rightAvatarImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(69)
            make.height.equalTo(89)
        }
        
        // 右侧名字（伴侣）
        rightNameLabel = UILabel()
        rightNameLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        rightNameLabel.textColor = .color(hexString: "#322D3A")
        rightNameLabel.textAlignment = .center
        unlinkContainerView.addSubview(rightNameLabel)
        rightNameLabel.snp.makeConstraints { make in
            make.centerX.equalTo(rightContainerView)
            make.top.equalTo(rightContainerView.snp.bottom).offset(6)
        }
        
        loadUnlinkAvatars()
        
        middleLabel = UILabel()
        middleLabel.text = "Are you sure you want to disconnect your partner?"
        middleLabel.textColor = .color(hexString: "#000000")
        middleLabel.numberOfLines = 0
        middleLabel.textAlignment = .center
        middleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
        view.addSubview(middleLabel)
        
        middleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(unlinkContainerView.snp.bottom).offset(35)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        bottomMiddleLabel = UILabel()
        bottomMiddleLabel.text = "After unbinding, tasks, points, and wishlists will no longer be shared. This is an important step—please confirm once more."
        bottomMiddleLabel.numberOfLines = 0
        bottomMiddleLabel.textAlignment = .center
        bottomMiddleLabel.textColor = .color(hexString: "#999DAB")
        bottomMiddleLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        view.addSubview(bottomMiddleLabel)
        
        bottomMiddleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(middleLabel.snp.bottom).offset(12)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.layer.borderWidth = 1
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-4)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
        
    }
    
    /// 加载 Unlink 页上方两个用户头像（左自己、右伴侣）。左侧/右侧背景根据性别；中间爱心根据双方性别组合。
    private func loadUnlinkAvatars() {
        let coupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
        let myGender = coupleInfo.myUserModel?.gender
        let partnerGender = coupleInfo.partnerUserModel?.gender
        
        // 左侧永远是自己，右侧永远是伴侣
        loadUnlinkAvatar(
            imageView: leftAvatarImageView,
            avatarString: coupleInfo.myAvatar,
            defaultImageName: defaultImageName(forGender: myGender)
        )
        loadUnlinkAvatar(
            imageView: rightAvatarImageView,
            avatarString: coupleInfo.partnerAvatar,
            defaultImageName: defaultImageName(forGender: partnerGender)
        )
        
        // 根据自己性别设置左侧背景：男→maleblueback，女→femalepinkback
        leftAvatarBackgroundView.image = UIImage(named: backgroundImageName(forGender: myGender))
        // 根据伴侣性别设置右侧背景
        rightAvatarBackgroundView.image = UIImage(named: backgroundImageName(forGender: partnerGender))
        
        // 根据双方性别设置中间爱心：自己男对方女→unlinkleftmale，自己男对方男→unlinkmale，自己女对方男→unlinkleftfemale，都女→unlinkfemale
        middleUserBreakIamge.image = UIImage(named: unlinkHeartImageName(myGender: myGender, partnerGender: partnerGender))
        
        // 设置名字：空/未知时显示默认名（与 SettingViewController、AssignPopup 一致）
        let myNameText = coupleInfo.myName.isEmpty || coupleInfo.myName == "未知" ? "Waves" : coupleInfo.myName
        let partnerNameText = coupleInfo.partnerName.isEmpty || coupleInfo.partnerName == "未知" ? "Momo" : coupleInfo.partnerName
        leftNameLabel.text = myNameText
        rightNameLabel.text = partnerNameText
    }
    
    /// 根据性别返回背景图名：男→maleblueback，女→femalepinkback
    private func backgroundImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleblueback" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femalepinkback" }
        return "maleblueback"
    }
    
    /// 根据双方性别返回中间爱心图名
    private func unlinkHeartImageName(myGender: String?, partnerGender: String?) -> String {
        let myIsFemale = isFemale(myGender)
        let myIsMale = isMale(myGender)
        let partnerIsFemale = isFemale(partnerGender)
        let partnerIsMale = isMale(partnerGender)
        if myIsMale && partnerIsFemale { return "unlinkleftmale" }
        if myIsMale && partnerIsMale { return "unlinkmale" }
        if myIsFemale && partnerIsMale { return "unlinkleftfemale" }
        if myIsFemale && partnerIsFemale { return "unlinkfemale" }
        return "unlinkmale" // 兜底
    }
    
    private func isFemale(_ gender: String?) -> Bool {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return false }
        let lower = g.lowercased()
        return lower == "female" || lower == "女性" || lower == "女"
    }
    
    private func isMale(_ gender: String?) -> Bool {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return false }
        let lower = g.lowercased()
        return lower == "male" || lower == "男性" || lower == "男"
    }
    
    /// 单个头像：有自定义头像则走缓存/抠图+白边+阴影，默认头像则只设图、不切图不阴影
    private func loadUnlinkAvatar(imageView: UIImageView, avatarString: String, defaultImageName: String) {
        if avatarString.isEmpty {
            imageView.image = UIImage(named: defaultImageName)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            return
        }
        if let cached = UserAvatarDisplayCache.shared.imageForSingle(avatarString: avatarString) {
            imageView.image = cached
            imageView.contentMode = .scaleAspectFit
            imageView.clipsToBounds = false
            imageView.applyAvatarCutoutShadow()
            return
        }
        let stillInViewHierarchy = imageView.superview != nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, stillInViewHierarchy else { return }
            guard let avatarImage = self.imageFromBase64String(avatarString) else { return }
            let outputSize = CGSize(width: 112, height: 112)
            ImageProcessor.shared.processAvatarWithAICutout(image: avatarImage, borderWidth: 8, outputSize: outputSize, cacheKey: avatarString) { [weak imageView] processed in
                let final = processed ?? avatarImage
                UserAvatarDisplayCache.shared.setSingle(final, for: avatarString)
                DispatchQueue.main.async {
                    guard let imageView = imageView, imageView.superview != nil else { return }
                    imageView.image = final
                    imageView.contentMode = .scaleAspectFit
                    imageView.clipsToBounds = false
                    imageView.applyAvatarCutoutShadow()
                }
            }
        }
    }
    
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        guard !base64String.isEmpty, base64String.count < 2_000_000 else { return nil }
        var base64 = base64String
        if base64.hasPrefix("data:image/"), let range = base64.range(of: ",") { base64 = String(base64[range.upperBound...]) }
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: imageData)
    }
    
    /// 根据性别返回默认头像图名
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        return "maleImage"
    }
    
    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    /// 强引用「Before you continue」专用弹窗，避免被释放
    private var beforeUnlinkPopup: BeforeUnlinkConfirmPopup?
    
    @objc func continueButtonTapped() {
        beforeUnlinkPopup = BeforeUnlinkConfirmPopup(
            confirmBlock: { [weak self] in
                guard let self = self else { return }
                self.beforeUnlinkPopup = nil
                self.performUnlink()
            },
            cancelBlock: { [weak self] in
                self?.beforeUnlinkPopup = nil
            }
        )
        if beforeUnlinkPopup?.show() != true {
            beforeUnlinkPopup = nil
            performUnlink()
        }
    }
    
    /// 被动端监听到对方断开时也需要删本地共享数据，与主动断开共用同一套清理
    static func deleteAllLocalSharedDataForUnlink() {
        let context = NSManagedObjectContext.mr_default()
        context.performAndWait {
            if let tasks = ListModel.mr_findAll(in: context) as? [ListModel], !tasks.isEmpty {
                for model in tasks { model.mr_deleteEntity(in: context) }
                print("✅ 已删除本地任务 \(tasks.count) 条")
            }
            if let wishes = PointsModel.mr_findAll(in: context) as? [PointsModel], !wishes.isEmpty {
                for model in wishes { model.mr_deleteEntity(in: context) }
                print("✅ 已删除本地愿望 \(wishes.count) 条")
            }
            if let annis = AnniModel.mr_findAll(in: context) as? [AnniModel], !annis.isEmpty {
                for model in annis { model.mr_deleteEntity(in: context) }
                print("✅ 已删除本地纪念日 \(annis.count) 条")
            }
            do {
                try context.save()
                context.mr_saveToPersistentStoreAndWait()
            } catch {
                print("❌ 删除本地共享数据保存失败: \(error.localizedDescription)")
            }
        }
        DispatchQueue.main.async {
            DbManager.manager.loadContent()
            PointsManger.manager.loadContent()
            AnniManger.manager.loadContent()
        }
    }
    
    // ✅ Execute unlink: Delete all Firebase data except users/{UUID} documents (managed by UserManger)
    // ✅ 保留：users/{currentUUID} 和 users/{partnerUUID} 文档（由 UserManger 管理）
    // ✅ 删除：couples/{coupleId} 及其所有子集合、linked_couples、annis/{coupleId}/anni 等所有共享数据
    private func performUnlink() {
        guard let coupleId = CoupleStatusManager.getPartnerId() else {
            AlertManager.showSingleButtonAlert(message: "Link information not found", target: self)
            return
        }
        
        // ✅ 标记为本机主动断开：被动端监听到对端 isInLinkedState=false 时不会误弹「被对方断开」页
        CoupleStatusManager.shared.unlinkInitiatedByCurrentUser = true
        
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
        let partnerUUID = partnerUser?.id ?? ""
        
        // Show loading alert
        let loadingAlert = UIAlertController(title: "Unlinking...", message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        
        // ✅ ========== 断开链接流程说明 ==========
        // ✅ 第一步：更新双方用户的isInLinkedState=false到Firebase（通知对方设备）
        // ✅ 第二步：删除所有共享数据（couples、linked_couples、annis等）
        // ✅ 第三步：清除本地状态
        // ✅ 保留：users/{currentUUID} 和 users/{partnerUUID} 文档（只更新isInLinkedState字段）
        // ✅ ===================================
        
        // ✅ 第一步：更新双方用户的 isInLinkedState=false 且清除 partner8digitId（在删除couples文档之前）
        // 这样对方设备可以通过 UserManger 的监听器检测到状态变化，且被断开方 Firebase 里不再保留对方的 ID
        dispatchGroup.enter()
        db.collection("users").document(currentUUID).updateData([
            "isInLinkedState": false,
            "partner8digitId": "",  // ✅ 清除当前用户文档中的伴侣 ID
            "serverTimestamp": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("❌ 更新当前用户isInLinkedState失败: \(error.localizedDescription)")
            } else {
                print("✅ 已更新当前用户isInLinkedState=false，并清除partner8digitId")
            }
            dispatchGroup.leave()
        }
        
        // ✅ 更新对方用户：isInLinkedState=false 且清除 partner8digitId（被断开方不再保留你的 ID）
        if !partnerUUID.isEmpty {
            dispatchGroup.enter()
            db.collection("users").document(partnerUUID).updateData([
                "isInLinkedState": false,
                "partner8digitId": "",  // ✅ 关键：清除对方文档里存的“我的”8位ID，断彻底
                "serverTimestamp": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("❌ 更新对方用户isInLinkedState/partner8digitId失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已更新对方用户isInLinkedState=false，并清除对方文档中的partner8digitId")
                }
                dispatchGroup.leave()
            }
        }
        
        // ✅ ========== 删除策略说明 ==========
        // ✅ 保留：users/{currentUUID} 和 users/{partnerUUID} 文档（只更新isInLinkedState字段）
        // ✅ 删除：以下所有共享数据
        //   1. couples/{coupleId} 及其所有子集合（items, notification_tasks, linkInfo, score_records, total_scores, wish）
        //   2. linked_couples 记录
        //   3. annis/{coupleId}/anni 纪念日数据
        //   4. users/{UUID}/userInfo/{partnerUUID}（旧路径，兼容性删除）
        // ✅ ===================================
        
        // ✅ 第二步：删除 couples/{coupleId} 的所有子集合
        // 注意：Firestore 删除父文档不会自动删除子集合，需要手动删除
        // ✅ 注意：不删除 users/{UUID} 文档本身，只删除共享数据
        
        // 2.1 删除 items（任务）
        dispatchGroup.enter()
        db.collection("couples").document(coupleId).collection("items").getDocuments { snapshot, error in
            if let error = error {
                print("❌ 获取任务列表失败: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let batch = db.batch()
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ 删除任务失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除任务（共\(snapshot?.documents.count ?? 0)条）")
                }
                dispatchGroup.leave()
            }
        }
        
        // 2.2 删除 notification_tasks（通知任务）
        dispatchGroup.enter()
        db.collection("couples").document(coupleId).collection("notification_tasks").getDocuments { snapshot, error in
            if let error = error {
                print("❌ 获取通知任务列表失败: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("ℹ️ 没有通知任务需要删除")
                dispatchGroup.leave()
                return
            }
            
            // 删除所有用户的通知任务子集合
            let deleteGroup = DispatchGroup()
            documents.forEach { userDoc in
                // 删除 tasks 子集合
                deleteGroup.enter()
                userDoc.reference.collection("tasks").getDocuments { taskSnapshot, taskError in
                    if let taskError = taskError {
                        print("❌ 获取 tasks 失败: \(taskError.localizedDescription)")
                        deleteGroup.leave()
                        return
                    }
                    
                    guard let taskDocs = taskSnapshot?.documents, !taskDocs.isEmpty else {
                        deleteGroup.leave()
                        return
                    }
                    
                    let batch = db.batch()
                    taskDocs.forEach { taskDoc in
                        batch.deleteDocument(taskDoc.reference)
                    }
                    batch.commit { _ in
                        deleteGroup.leave()
                    }
                }
                
                // 删除 anni_tasks 子集合
                deleteGroup.enter()
                userDoc.reference.collection("anni_tasks").getDocuments { anniSnapshot, anniError in
                    if let anniError = anniError {
                        print("❌ 获取 anni_tasks 失败: \(anniError.localizedDescription)")
                        deleteGroup.leave()
                        return
                    }
                    
                    guard let anniDocs = anniSnapshot?.documents, !anniDocs.isEmpty else {
                        deleteGroup.leave()
                        return
                    }
                    
                    let batch = db.batch()
                    anniDocs.forEach { anniDoc in
                        batch.deleteDocument(anniDoc.reference)
                    }
                    batch.commit { _ in
                        deleteGroup.leave()
                    }
                }
            }
            
            // 等待所有子集合删除完成，再删除父文档
            deleteGroup.notify(queue: .main) {
                let batch = db.batch()
                documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }
                batch.commit { error in
                    if let error = error {
                        print("❌ 删除通知任务失败: \(error.localizedDescription)")
                    } else {
                        print("✅ 已删除通知任务（共\(documents.count)条）")
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // 2.3 删除 linkInfo
        dispatchGroup.enter()
        db.collection("couples").document(coupleId).collection("linkInfo").getDocuments { snapshot, error in
            if let error = error {
                print("❌ 获取链接信息失败: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let batch = db.batch()
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ 删除链接信息失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除链接信息（共\(snapshot?.documents.count ?? 0)条）")
                }
                dispatchGroup.leave()
            }
        }
        
        // 2.4 删除 score_records（分数记录）
        dispatchGroup.enter()
        db.collection("couples").document(coupleId).collection("score_records").getDocuments { snapshot, error in
            if let error = error {
                print("❌ 获取分数记录失败: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let batch = db.batch()
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ 删除分数记录失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除分数记录（共\(snapshot?.documents.count ?? 0)条）")
                }
                dispatchGroup.leave()
            }
        }
        
        // 2.5 删除 total_scores（总分）
        dispatchGroup.enter()
        db.collection("couples").document(coupleId).collection("total_scores").getDocuments { snapshot, error in
            if let error = error {
                print("❌ 获取总分失败: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let batch = db.batch()
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ 删除总分失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除总分（共\(snapshot?.documents.count ?? 0)条）")
                }
                dispatchGroup.leave()
            }
        }
        
        // 2.6 最后删除 couples/{coupleId} 主文档
        dispatchGroup.enter()
        db.collection("couples").document(coupleId).delete { error in
            if let error = error {
                print("❌ 删除 couples 主文档失败: \(error.localizedDescription)")
            } else {
                print("✅ 已删除 couples/\(coupleId) 主文档")
            }
            dispatchGroup.leave()
        }
        
        // 3. 删除 linked_couples 记录（两个用户的 code 都需要删除）
        // ✅ 修复：coupleId 是两个邀请码的最小值，我们需要删除两个邀请码对应的 linked_couples 记录
        // ✅ 必须先等「自己的 linked_couples」删除完成再 resetAllStatus，否则会启动全局监听器时文档仍存在，误判为「被链接」导致自动重新链接
        dispatchGroup.enter()
        // ✅ 防护：确保此 enter 一定有一次 leave（避免 Firebase 不回调时永久卡住）
        var linkedCouplesDidLeave = false
        let linkedCouplesLeaveOnce: () -> Void = {
            guard !linkedCouplesDidLeave else { return }
            linkedCouplesDidLeave = true
            dispatchGroup.leave()
        }
        // ✅ 超时保护：若 Firebase 长时间未回调，强制 leave，避免界面一直卡住
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { linkedCouplesLeaveOnce() }
        
        // ✅ 先删除自己的 linked_couples 记录，并等待完成（否则 resetAllStatus 后全局监听器会立刻读到旧文档并自动重新链接）
        let linkedCouplesInnerGroup = DispatchGroup()
        if let ownCode = CoupleStatusManager.shared.ownInvitationCode {
            linkedCouplesInnerGroup.enter()
            db.collection("linked_couples").document(ownCode).delete { error in
                if let error = error {
                    print("❌ 删除 linked_couples/\(ownCode) 失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除 linked_couples/\(ownCode)")
                }
                linkedCouplesInnerGroup.leave()
            }
        }
        
        // ✅ 等「自己的 + 伴侣方的」linked_couples 都删除后再 leave，避免 resetAllStatus 后全局监听器读到残留文档
        linkedCouplesInnerGroup.notify(queue: .main) { linkedCouplesLeaveOnce() }
        
        // ✅ 关键修复：coupleId 是两个邀请码的最小值
        // 如果 coupleId == ownCode，那么伴侣的邀请码是另一个值（需要从 linked_couples 中查找）
        // 如果 coupleId != ownCode，那么 coupleId 就是伴侣的邀请码
        linkedCouplesInnerGroup.enter()
        if let ownCode = CoupleStatusManager.shared.ownInvitationCode, coupleId == ownCode {
            // coupleId 是自己的邀请码，需要查找伴侣的邀请码
            // 从 linked_couples 集合中查找所有文档，找到与当前 coupleId 相关的记录
            db.collection("linked_couples").getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 获取 linked_couples 列表失败: \(error.localizedDescription)")
                    linkedCouplesInnerGroup.leave()
                    return
                }
                
                guard let docs = snapshot?.documents, !docs.isEmpty else {
                    print("ℹ️ linked_couples 集合为空")
                    linkedCouplesInnerGroup.leave()
                    return
                }
                
                // ✅ 查找伴侣的邀请码：找到所有 code > ownCode 的邀请码，其中 min(code, ownCode) = ownCode = coupleId
                let deleteGroup = DispatchGroup()
                var deletedCount = 0
                
                for doc in docs {
                    let code = doc.documentID
                    if code == ownCode { continue }
                    
                    deleteGroup.enter()
                    db.collection("linked_couples").document(code).delete { error in
                        if let error = error {
                            print("⚠️ 删除 linked_couples/\(code) 失败: \(error.localizedDescription)")
                        } else {
                            deletedCount += 1
                            print("✅ 已删除 linked_couples/\(code)")
                        }
                        deleteGroup.leave()
                    }
                }
                
                deleteGroup.notify(queue: .main) {
                    print("✅ 已删除 \(deletedCount) 个 linked_couples 记录")
                    linkedCouplesInnerGroup.leave()
                }
            }
        } else {
            // coupleId 不是自己的邀请码，说明 coupleId 就是伴侣的邀请码（或两个邀请码的最小值）
            db.collection("linked_couples").document(coupleId).delete { error in
                if let error = error {
                    print("❌ 删除 linked_couples/\(coupleId) 失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除 linked_couples/\(coupleId)")
                }
                linkedCouplesInnerGroup.leave()
            }
        }
        
        // ✅ 优化：4. 删除 couples/{coupleId}/wish 愿望清单（统一路径）
        dispatchGroup.enter()
        db.collection("couples").document(coupleId).collection("wish").getDocuments { snapshot, error in
            if let error = error {
                print("❌ 获取愿望清单失败: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let batch = db.batch()
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ 删除愿望清单失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除愿望清单（共\(snapshot?.documents.count ?? 0)条）")
                }
                dispatchGroup.leave()
            }
        }
        
        // 5. 删除 annis/{coupleId}/anni 纪念日数据
        dispatchGroup.enter()
        db.collection("annis").document(coupleId).collection("anni").getDocuments { snapshot, error in
            if let error = error {
                print("❌ 获取纪念日数据失败: \(error.localizedDescription)")
                dispatchGroup.leave()
                return
            }
            
            let batch = db.batch()
            snapshot?.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            
            batch.commit { error in
                if let error = error {
                    print("❌ 删除纪念日数据失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已删除纪念日数据（共\(snapshot?.documents.count ?? 0)条）")
                }
                dispatchGroup.leave()
            }
        }
        
        // ✅ 6. 注意：保留 users/{currentUUID} 和 users/{partnerUUID} 文档（由 UserManger 管理）
        // ✅ 不删除 users 集合中的文档，只删除其他共享数据
        // ✅ 如果存在旧的 userInfo 子集合路径，也删除（兼容旧版本）
        if !partnerUUID.isEmpty {
            // 删除自己用户信息中的伴侣信息（旧路径，兼容性删除）
            dispatchGroup.enter()
            db.collection("users")
                .document(currentUUID)
                .collection("userInfo")
                .document(partnerUUID)
                .delete { error in
                    if let error = error {
                        // ✅ 如果路径不存在，不报错（可能是新版本架构）
                        if (error as NSError).code != 5 { // 5 = NOT_FOUND
                            print("⚠️ 删除 users/\(currentUUID)/userInfo/\(partnerUUID) 失败: \(error.localizedDescription)")
                        } else {
                            print("ℹ️ users/\(currentUUID)/userInfo/\(partnerUUID) 不存在（可能是新版本架构）")
                        }
                    } else {
                        print("✅ 已删除 users/\(currentUUID)/userInfo/\(partnerUUID)")
                    }
                    dispatchGroup.leave()
                }
            
            // 删除伴侣用户信息中的自己信息（旧路径，兼容性删除）
            dispatchGroup.enter()
            db.collection("users")
                .document(partnerUUID)
                .collection("userInfo")
                .document(currentUUID)
                .delete { error in
                    if let error = error {
                        // ✅ 如果路径不存在，不报错（可能是新版本架构）
                        if (error as NSError).code != 5 { // 5 = NOT_FOUND
                            print("⚠️ 删除 users/\(partnerUUID)/userInfo/\(currentUUID) 失败: \(error.localizedDescription)")
                        } else {
                            print("ℹ️ users/\(partnerUUID)/userInfo/\(currentUUID) 不存在（可能是新版本架构）")
                        }
                    } else {
                        print("✅ 已删除 users/\(partnerUUID)/userInfo/\(currentUUID)")
                    }
                    dispatchGroup.leave()
                }
        }
        
        // 等待所有删除操作完成
        dispatchGroup.notify(queue: .main) { [weak self] in
            loadingAlert.dismiss(animated: true) {
                // ✅ 清除本地状态（设置所有判断链接的标识为 false）
                CoupleStatusManager.shared.resetAllStatus()
                
                // ✅ 清除 UserDefaults 中的链接状态（兼容旧版本）
                UserDefaults.standard.set(false, forKey: "isCoupleLinked")
                UserDefaults.standard.synchronize()
                
                // ✅ 断开链接：删除本地所有共享数据，仅保留用户个人信息（UserModel 不删）
                UnlinkViewController.deleteAllLocalSharedDataForUnlink()
                
                // ✅ 清除本地 Core Data 中的伴侣信息
                if !partnerUUID.isEmpty {
                    if let partnerModel = UserManger.manager.getUserModelByUUID(partnerUUID) {
                        partnerModel.isInLinkedState = false
                        // ✅ 同步到Firebase（确保对方设备也能收到更新）
                        UserManger.manager.updateModel(partnerModel)
                    }
                }
                
                // ✅ 确保当前用户的 isInLinkedState 也为 false
                if let currentUserModel = UserManger.manager.getUserModelByUUID(currentUUID) {
                    currentUserModel.isInLinkedState = false
                    // ✅ 同步到Firebase（确保对方设备也能收到更新）
                    UserManger.manager.updateModel(currentUserModel)
                }
                
                // ✅ 保存CoreData更改
                NSManagedObjectContext.mr_default().mr_saveToPersistentStoreAndWait()
                
                print("✅ All link status cleared: isUserLinked = false, isCoupleLinked = false")
                guard let self = self else { return }
                // ✅ 主动断开方：不进入 CheekBootPageView，只正常 back 返回上一页
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self else { return }
                    CoupleStatusManager.shared.unlinkInitiatedByCurrentUser = false
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
    
}
