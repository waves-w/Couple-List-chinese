//
//  AssignPopupSingle.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import FFPopup
import CoreData
import MagicalRecord

class AnniassignPopup: NSObject {
    var backView: UIView!
    var hintView: UIView!
    var topLine: UIView!
    var closeButton: UIButton!
    var popup: WavesPopup!
    var bottomSpacing: CGFloat = 0
    var titleLabel: UILabel!
    // ✅ 跟踪弹窗显示状态
    private var isPopupShowing = false
    var UserAView: UIView!
    var UserBView: UIView!
    var manImage: UIImageView!
    var womanImage: UIImageView!
    var UserAiconImageView: UIImageView!
    var UserBiconImageView: UIImageView!
    
    // ✅ 新增：用户名字标签
    var UserANameLabel: UILabel!
    var UserBNameLabel: UILabel!
    
    let selectedImage = UIImage(named: "assignSelect")
    let unselectedImage = UIImage(named: "assignUnselect")
    private var selectedAssignIndex: Int = 0
    var isUserASelected: Bool = false
    var isUserBSelected: Bool = false
    var continueButton: UIButton!
    var assignselected: ((Int) -> Void)?
    
    private let kSelectedAssignIndex = "kSelectedAssignIndex"
    
    override init() {
        super.init()
        setupUI()
        // ✅ 仅在用户修改头像时刷新弹窗内头像
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avatarDidUpdate),
            name: UserManger.avatarDidUpdateNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        ImageProcessor.shared.cancelAllProcessing()
    }
    
    /// 当前期望的伴侣/自己头像 key，用于避免「先选自定义再选默认」时过期异步结果覆盖导致重叠
    private var currentPartnerAvatarKey: String?
    private var currentMyAvatarKey: String?
    
    /// 仅在用户修改头像时刷新弹窗内头像（弹窗显示中才刷新）
    @objc private func avatarDidUpdate() {
        guard isPopupShowing else { return }
        loadUserAvatarsAndNames()
    }
    
    private func setupUI() {
        backView = UIView()
        backView.layer.cornerRadius = 24
        backView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backView.clipsToBounds = true
        backView.backgroundColor = .white
        
        hintView = UIView()
        hintView.backgroundColor = .clear
        backView.addSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.height.equalTo(20)
            make.width.equalTo(300)
            make.centerX.equalToSuperview()
        }
        
        topLine = UIView()
        topLine.layer.cornerRadius = 2.5
        topLine.backgroundColor = .color(hexString: "#DED9ED")
        backView.addSubview(topLine)
        topLine.snp.makeConstraints { make in
            make.top.equalTo(6)
            make.centerX.equalToSuperview()
            make.width.equalTo(35)
            make.height.equalTo(5)
        }
        
        closeButton = UIButton()
        closeButton.setImage(UIImage(named: "listback"), for: .normal)
        closeButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.dismiss(animated: true)
        }
        backView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(20)
            make.width.height.equalTo(28)
        }
        
        titleLabel = UILabel()
        titleLabel.text = "Assign"
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        titleLabel.textColor = .color(hexString: "#111111")
        backView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton)
        }
        
        let manView = UIView()
        backView.addSubview(manView)
        
        manView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(217.0 / 375.0)
            make.height.equalTo(89)
            make.top.equalTo(closeButton.snp.bottom).offset(17)
        }
        
        // ✅ 左边：自己（UserB = Oneself）；占位用中性图，加载时按自己性别显示默认头像
        womanImage = UIImageView(image: UIImage(named: "userText"))
        womanImage.contentMode = .scaleAspectFill
        womanImage.clipsToBounds = true
        womanImage.layer.cornerRadius = 30
        womanImage.isUserInteractionEnabled = true // ✅ 启用交互，才能响应手势
        manView.addSubview(womanImage)
        
        womanImage.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.width.equalTo(69)
            make.height.equalToSuperview()
        }
        
        // ✅ 右边：伴侣（UserA = Partner）；占位用中性图，加载时按伴侣性别显示默认头像
        manImage = UIImageView(image: UIImage(named: "userText"))
        manImage.contentMode = .scaleAspectFill
        manImage.clipsToBounds = true
        manImage.layer.cornerRadius = 30
        manImage.isUserInteractionEnabled = true // ✅ 启用交互，才能响应手势
        manView.addSubview(manImage)
        
        manImage.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.top.equalToSuperview()
            make.width.equalTo(69)
            make.height.equalToSuperview()
        }
        // ✅ 左边：自己（UserB = Oneself）= assignIndex=1（给自己）
        UserBView = UIView()
        UserBView.isUserInteractionEnabled = true
        UserBView.backgroundColor = .clear // 确保视图可见（调试用，可以移除）
        backView.addSubview(UserBView)
        
        UserBView.snp.makeConstraints { make in
            make.centerX.equalTo(womanImage)
            make.top.equalTo(manView.snp.bottom).offset(9)
            make.height.greaterThanOrEqualTo(30) // ✅ 确保有足够的高度用于点击
        }
        
        UserBiconImageView = UIImageView()
        UserBiconImageView.image = unselectedImage
        UserBiconImageView.isUserInteractionEnabled = false // ✅ 让点击事件传递给父视图
        UserBView.addSubview(UserBiconImageView)
        
        UserBiconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24) // ✅ 设置明确的尺寸
        }
        
        UserBNameLabel = UILabel()
        UserBNameLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        UserBNameLabel.textColor = .color(hexString: "#322D3A")
        UserBNameLabel.isUserInteractionEnabled = false // ✅ 让点击事件传递给父视图
        UserBView.addSubview(UserBNameLabel)
        
        UserBNameLabel.snp.makeConstraints { make in
            make.left.equalTo(UserBiconImageView.snp.right).offset(3)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualToSuperview() // ✅ 改为 lessThanOrEqualTo，避免约束冲突
        }
        
        // ✅ 右边：伴侣（UserA = Partner）= assignIndex=0（给对方）
        UserAView = UIView()
        UserAView.isUserInteractionEnabled = true
        UserAView.backgroundColor = .clear // 确保视图可见（调试用，可以移除）
        backView.addSubview(UserAView)
        
        UserAView.snp.makeConstraints { make in
            make.centerX.equalTo(manImage)
            make.top.equalTo(manView.snp.bottom).offset(9)
            make.height.greaterThanOrEqualTo(30) // ✅ 确保有足够的高度用于点击
        }
        
        UserAiconImageView = UIImageView()
        UserAiconImageView.image = unselectedImage
        UserAiconImageView.isUserInteractionEnabled = false // ✅ 让点击事件传递给父视图
        UserAView.addSubview(UserAiconImageView)
        
        UserAiconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24) // ✅ 设置明确的尺寸
        }
        
        UserANameLabel = UILabel()
        UserANameLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        UserANameLabel.textColor = .color(hexString: "#322D3A")
        UserANameLabel.isUserInteractionEnabled = false // ✅ 让点击事件传递给父视图
        UserAView.addSubview(UserANameLabel)
        
        UserANameLabel.snp.makeConstraints { make in
            make.left.equalTo(UserAiconImageView.snp.right).offset(3)
            make.centerY.equalTo(UserAiconImageView)
            make.right.lessThanOrEqualToSuperview() // ✅ 改为 lessThanOrEqualTo，避免约束冲突
        }
        
        
        // ✅ UserA（伴侣，右边）的点击手势
        let tapA = UITapGestureRecognizer(target: self, action: #selector(handleUserATap))
        UserAView.addGestureRecognizer(tapA)
        
        // ✅ manImage 是 UserA（伴侣，右边）的头像，应该绑定 handleUserATap
        let tapManImage = UITapGestureRecognizer(target: self, action: #selector(handleUserATap))
        manImage.addGestureRecognizer(tapManImage)
        
        // ✅ UserB（自己，左边）的点击手势
        let tapB = UITapGestureRecognizer(target: self, action: #selector(handleUserBTap))
        UserBView.addGestureRecognizer(tapB)
        
        // ✅ womanImage 是 UserB（自己，左边）的头像，应该绑定 handleUserBTap
        let tapWomanImage = UITapGestureRecognizer(target: self, action: #selector(handleUserBTap))
        womanImage.addGestureRecognizer(tapWomanImage)
        
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.layer.borderWidth = 1
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            
            // ✅ 安全检查：确保有选择
            guard self.selectedAssignIndex >= 0 else {
                return
            }
            
            // ✅ 先关闭弹窗
            self.dismiss(animated: true)
            
            // ✅ 然后调用回调（让外部处理逻辑）
            if let callback = self.assignselected {
                callback(self.selectedAssignIndex)
            }
        }
        backView.addSubview(continueButton)
        
        continueButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottomMargin.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(56)
        }
        
        popup = WavesPopup(contentView: backView,
                           showType: .slideInFromBottom,
                           dismissType: .slideOutToBottom,
                           maskType: .dimmed,
                           dismissOnBackgroundTouch: true,
                           dismissOnContentTouch: false,
                           dismissPanView: hintView)
    }
    
    /// ✅ Anni 用：点击 A 切换 A 的选中状态（可多选：仅 A、仅 B、或双方）
    @objc private func handleUserATap() {
        isUserASelected.toggle()
        updateAssignIndexAndUI()
    }
    
    /// ✅ Anni 用：点击 B 切换 B 的选中状态（可多选）
    @objc private func handleUserBTap() {
        isUserBSelected.toggle()
        updateAssignIndexAndUI()
    }
    
    private func updateAssignIndexAndUI() {
        if isUserASelected && isUserBSelected {
            selectedAssignIndex = TaskAssignIndex.both.rawValue
        } else if isUserASelected {
            selectedAssignIndex = TaskAssignIndex.partner.rawValue
        } else if isUserBSelected {
            selectedAssignIndex = TaskAssignIndex.myself.rawValue
        } else {
            selectedAssignIndex = -1
        }
        UserAiconImageView.image = isUserASelected ? selectedImage : unselectedImage
        UserBiconImageView.image = isUserBSelected ? selectedImage : unselectedImage
        continueButton.isEnabled = selectedAssignIndex >= 0
        continueButton.alpha = selectedAssignIndex >= 0 ? 1.0 : 0.5
    }
    
    /// 展示弹窗（Anni 用：支持 0=伴侣、1=自己、2=双方）
    func show(width: CGFloat, bottomSpacing: CGFloat, initialIndex: Int? = nil) {
        guard popup != nil, backView != nil else {
            print("❌ AssignPopup: UI元素未初始化，无法显示弹窗")
            return
        }
        let index = initialIndex ?? -1
        if index >= 0 && index <= TaskAssignIndex.both.rawValue {
            selectedAssignIndex = index
            switch index {
            case TaskAssignIndex.partner.rawValue:
                isUserASelected = true
                isUserBSelected = false
            case TaskAssignIndex.myself.rawValue:
                isUserASelected = false
                isUserBSelected = true
            case TaskAssignIndex.both.rawValue:
                isUserASelected = true
                isUserBSelected = true
            default:
                break
            }
            UserAiconImageView.image = isUserASelected ? selectedImage : unselectedImage
            UserBiconImageView.image = isUserBSelected ? selectedImage : unselectedImage
            continueButton.isEnabled = true
            continueButton.alpha = 1.0
        } else {
            selectedAssignIndex = -1
            isUserASelected = false
            isUserBSelected = false
            UserAiconImageView.image = unselectedImage
            UserBiconImageView.image = unselectedImage
            continueButton.isEnabled = false
            continueButton.alpha = 0.5
        }
        
        self.layout(width: width, bottomSpacing: bottomSpacing)
        self.popup.show(layout: .init(horizontal: .center, vertical: .bottom))
        self.isPopupShowing = true // ✅ 标记弹窗已显示
        
        // ✅ 与各页一致：进一次不刷新，先用全局缓存；仅识别到修改时整体刷新
        let coupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
        let cache = UserAvatarDisplayCache.shared
        if let partnerImg = cache.imageForSingle(avatarString: coupleInfo.partnerAvatar), !coupleInfo.partnerAvatar.isEmpty {
            manImage.image = partnerImg
            manImage.contentMode = .scaleAspectFit
        } else {
            manImage.image = UIImage(named: defaultImageName(forGender: coupleInfo.partnerUserModel?.gender))
            manImage.contentMode = .scaleAspectFill
        }
        if let myImg = cache.imageForSingle(avatarString: coupleInfo.myAvatar), !coupleInfo.myAvatar.isEmpty {
            womanImage.image = myImg
            womanImage.contentMode = .scaleAspectFit
        } else {
            womanImage.image = UIImage(named: defaultImageName(forGender: coupleInfo.myUserModel?.gender))
            womanImage.contentMode = .scaleAspectFill
        }
        // ✅ 只做“用当前数据更新名字+头像”：有缓存直接用，无缓存才异步加载；只有数据缺失时才走 Firebase 完整刷新
        applyCurrentCoupleInfo()
    }
    
    // ✅ 添加 dismiss 方法，用于关闭弹窗时更新状态
    func dismiss(animated: Bool) {
        self.popup.dismiss(animated: animated)
        self.isPopupShowing = false // ✅ 标记弹窗已关闭
    }
    
    
    /// 弹窗显示时只做轻量更新：用当前本地数据更新名字和头像（有缓存直接用，无缓存才异步加载）。不做 Firebase、不清缓存。
    private func applyCurrentCoupleInfo() {
        let coupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
        let needSyncMyInfo = coupleInfo.myAvatar.isEmpty || coupleInfo.myName.isEmpty || coupleInfo.myName == "未知"
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        if needSyncMyInfo && !currentUUID.isEmpty {
            loadUserAvatarsAndNames()
            return
        }
        updateUIWithCoupleInfo(coupleInfo: coupleInfo)
    }
    
    // ✅ 完整刷新：含 Firebase 同步、重试等，仅在「数据缺失」或「userDataDidUpdate」时调用
    private func loadUserAvatarsAndNames() {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        let coupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
        
        // ✅ 如果自己的名字为空或"未知"，或者头像为空，尝试从Firebase同步（不阻塞UI）
        let needSyncMyInfo = coupleInfo.myAvatar.isEmpty ||
        coupleInfo.myName.isEmpty ||
        coupleInfo.myName == "未知"
        
        if needSyncMyInfo && !currentUUID.isEmpty {
            let db = Firestore.firestore()
            db.collection("users").document(currentUUID).getDocument { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    _ = error
                    DispatchQueue.main.async {
                        self.updateUIWithCoupleInfo(coupleInfo: coupleInfo)
                    }
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    DispatchQueue.main.async {
                        self.updateUIWithCoupleInfo(coupleInfo: coupleInfo)
                    }
                    return
                }
                
                guard let data = snapshot.data() else {
                    DispatchQueue.main.async {
                        self.updateUIWithCoupleInfo(coupleInfo: coupleInfo)
                    }
                    return
                }
                
                // ✅ 获取名字和头像URL并更新CoreData
                var needUpdate = false
                if let myModel = UserManger.manager.getUserModelByUUID(currentUUID) {
                    // ✅ 更新名字（如果Firebase中有且本地为空或"未知"）
                    if let firebaseName = data["userName"] as? String,
                       !firebaseName.isEmpty {
                        let shouldUpdateName = (myModel.userName == nil || myModel.userName?.isEmpty == true || myModel.userName == "未知")
                        if shouldUpdateName {
                            myModel.userName = firebaseName
                            needUpdate = true
                        }
                    }
                    
                    // ✅ 更新头像（如果Firebase中有且本地为空）
                    if let avatarURL = data["avatarImageURL"] as? String,
                       !avatarURL.isEmpty {
                        let shouldUpdateAvatar = (myModel.avatarImageURL == nil || myModel.avatarImageURL?.isEmpty == true)
                        if shouldUpdateAvatar {
                            myModel.avatarImageURL = avatarURL
                            needUpdate = true
                        }
                    }
                    
                    // ✅ 保存CoreData（如果有更新，确保在主线程保存）
                    if needUpdate {
                        DispatchQueue.main.async {
                            do {
                                let context = NSManagedObjectContext.mr_default()
                                guard context.hasChanges else { return }
                                try context.save()
                            } catch { }
                        }
                    }
                }
                
                // ✅ 重新获取数据并更新UI（增加延迟，确保 CoreData 保存完成）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.isPopupShowing else { return }
                    let updatedCoupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
                    if updatedCoupleInfo.myName.isEmpty || updatedCoupleInfo.myName == "未知" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                            guard let self = self, self.isPopupShowing else { return }
                            let retryCoupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
                            self.updateUIWithCoupleInfo(coupleInfo: retryCoupleInfo)
                        }
                    } else {
                        self.updateUIWithCoupleInfo(coupleInfo: updatedCoupleInfo)
                    }
                }
            }
            return
        }
        
        // ✅ 如果名字是"未知"或空，尝试再次获取数据（可能 CoreData 正在更新中）
        if coupleInfo.myName.isEmpty || coupleInfo.myName == "未知" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.isPopupShowing else { return }
                let retryCoupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
                self.updateUIWithCoupleInfo(coupleInfo: retryCoupleInfo)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateUIWithCoupleInfo(coupleInfo: coupleInfo)
            }
        }
    }
    
    /// 根据用户设置的性别返回默认头像图片名（male/男 → maleImage，female/女 → femaleImage）
    private func defaultImageName(forGender gender: String?) -> String {
        guard let g = gender?.trimmingCharacters(in: .whitespaces), !g.isEmpty else { return "maleImage" }
        let lower = g.lowercased()
        if lower == "female" || lower == "女" { return "femaleImage" }
        if lower == "male" || lower == "男" { return "maleImage" }
        return "maleImage"
    }
    
    // ✅ 使用 CoupleInfo 结构体更新UI（从 Firebase users/{UUID} 获取数据）
    private func updateUIWithCoupleInfo(coupleInfo: UserManger.CoupleInfo) {
        guard let userBNameLabel = UserBNameLabel,
              let userANameLabel = UserANameLabel,
              let womanImg = womanImage,
              let manImg = manImage else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let userBNameLabel = self.UserBNameLabel,
                  let userANameLabel = self.UserANameLabel,
                  let womanImg = self.womanImage,
                  let manImg = self.manImage else { return }
            
            let myNameText = coupleInfo.myName.isEmpty || coupleInfo.myName == "未知" ? "Waves" : coupleInfo.myName
            userBNameLabel.text = myNameText
            
            var myAvatarString = coupleInfo.myAvatar
            if myAvatarString.isEmpty {
                let currentUUID = CoupleStatusManager.getUserUniqueUUID()
                if let myModel = UserManger.manager.getUserModelByUUID(currentUUID),
                   let avatarURL = myModel.avatarImageURL,
                   !avatarURL.isEmpty {
                    myAvatarString = avatarURL
                }
            }
            let myDefaultImage = self.defaultImageName(forGender: coupleInfo.myUserModel?.gender)
            self.loadAvatar(imageView: womanImg, avatarString: myAvatarString, defaultImage: myDefaultImage)
            
            let partnerNameText = coupleInfo.partnerName.isEmpty || coupleInfo.partnerName == "未知" ? "Momo" : coupleInfo.partnerName
            userANameLabel.text = partnerNameText
            
            var partnerAvatarString = coupleInfo.partnerAvatar
            if partnerAvatarString.isEmpty {
                if let partnerModel = coupleInfo.partnerUserModel,
                   let avatarURL = partnerModel.avatarImageURL,
                   !avatarURL.isEmpty {
                    partnerAvatarString = avatarURL
                }
            }
            let partnerDefaultImage = self.defaultImageName(forGender: coupleInfo.partnerUserModel?.gender)
            self.loadAvatar(imageView: manImg, avatarString: partnerAvatarString, defaultImage: partnerDefaultImage)
            
            userANameLabel.setNeedsDisplay()
            userBNameLabel.setNeedsDisplay()
            userANameLabel.setNeedsLayout()
            userBNameLabel.setNeedsLayout()
            userANameLabel.superview?.setNeedsLayout()
            userANameLabel.superview?.layoutIfNeeded()
            userBNameLabel.superview?.setNeedsLayout()
            userBNameLabel.superview?.layoutIfNeeded()
        }
    }
    
    // ✅ 提取：加载头像的通用方法（用全局缓存，与各页一致：进一次不刷新）
    private func loadAvatar(imageView: UIImageView, avatarString: String, defaultImage: String) {
        // ✅ 安全检查：确保 imageView 有效
        guard imageView.superview != nil else { return }
        // ✅ 记录本次要加载的 key，后续异步完成时只有仍匹配才设置，避免「先选自定义再选默认」后旧任务覆盖导致重叠
        if imageView === manImage { currentPartnerAvatarKey = avatarString }
        else if imageView === womanImage { currentMyAvatarKey = avatarString }
        
        // ✅ 如果头像字符串为空，直接使用默认头像，不检查缓存
        if avatarString.isEmpty {
            DispatchQueue.main.async { [weak self, weak imageView] in
                guard let imageView = imageView, imageView.superview != nil else { return }
                imageView.image = UIImage(named: defaultImage)
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
            }
            return
        }
        
        if let cachedImage = UserAvatarDisplayCache.shared.imageForSingle(avatarString: avatarString) {
            DispatchQueue.main.async { [weak self, weak imageView] in
                guard let self = self, let imageView = imageView, imageView.superview != nil else { return }
                if imageView === self.manImage, self.currentPartnerAvatarKey != avatarString { return }
                if imageView === self.womanImage, self.currentMyAvatarKey != avatarString { return }
                imageView.image = cachedImage
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = false
                imageView.applyAvatarCutoutShadow()
            }
            return
        }
        
        // ✅ 不再重复设置默认图：ImageView 在 setupUI 中已是 .man/.woman，避免闪一下
        
        // ✅ 解码后走与用户页一致的抠图+白边逻辑（processAvatarWithAICutout）
//        print("🔍 [AssignPopup] 开始解码Base64头像并抠图 - 字符串长度: \(avatarLength)")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                print("⚠️ [AssignPopup] self已释放，取消解码")
                return
            }
            guard self.popup != nil else {
                print("⚠️ [AssignPopup] 弹窗已关闭，取消头像加载")
                return
            }
            let decodeStartTime = Date()
            guard let avatarImage = self.imageFromBase64String(avatarString) else {
                let decodeDuration = Date().timeIntervalSince(decodeStartTime)
//                print("❌ [AssignPopup] Base64解码失败 - 耗时: \(String(format: "%.3f", decodeDuration))秒, 字符串长度: \(avatarLength)")
                return
            }
            let decodeDuration = Date().timeIntervalSince(decodeStartTime)
            print("✅ [AssignPopup] Base64解码成功 - 耗时: \(String(format: "%.3f", decodeDuration))秒, 图片尺寸: \(avatarImage.size)")
            // ✅ 弹窗头像显示尺寸 69×89，使用 2x 输出保证清晰度
            let popupOutputSize = CGSize(width: 138, height: 178)
            ImageProcessor.shared.processAvatarWithAICutout(image: avatarImage, borderWidth: 14, outputSize: popupOutputSize, cacheKey: avatarString) { [weak self] processedImage in
                guard let self = self else { return }
                let finalImage = processedImage ?? avatarImage
                UserAvatarDisplayCache.shared.setSingle(finalImage, for: avatarString)
                DispatchQueue.main.async { [weak self, weak imageView] in
                    guard let self = self, let imageView = imageView, imageView.superview != nil else { return }
                    guard self.popup != nil else { return }
                    // ✅ 若用户已改为默认头像，当前 key 已变，不再用本次结果覆盖，避免重叠
                    if imageView === self.manImage, self.currentPartnerAvatarKey != avatarString { return }
                    if imageView === self.womanImage, self.currentMyAvatarKey != avatarString { return }
                    // ✅ 用短时淡入替换，减少“闪一下”的观感
                    UIView.transition(with: imageView, duration: 0.2, options: .transitionCrossDissolve) {
                        imageView.image = finalImage
                        imageView.contentMode = .scaleAspectFit
                        imageView.clipsToBounds = false
                        imageView.applyAvatarCutoutShadow()
                    } completion: { _ in
                        print("✅ [AssignPopup] 头像已设置（抠图+白边）- 尺寸: \(finalImage.size)")
                    }
                }
            }
        }
    }
    
    func layout(width: CGFloat, bottomSpacing: CGFloat) {
        guard backView != nil else {
            print("❌ AssignPopup: UI元素未初始化，无法布局")
            return
        }
        self.bottomSpacing = bottomSpacing
        // ✅ 按比例 298/812 计算弹窗高度，与 AssignPopup 一致
        let screenHeight = UIScreen.main.bounds.height
        let contentHeight = screenHeight * (298 / 812)
        backView.bounds = CGRect(x: 0, y: 0, width: width, height: contentHeight)
    }
    
    // ✅ 从Base64字符串解码图片（添加异常处理，避免崩溃）
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        let startTime = Date()
        print("🔍 [AssignPopup] imageFromBase64String 开始 - 输入长度: \(base64String.count)")
        
        // ✅ 安全检查：空字符串
        guard !base64String.isEmpty else {
            print("❌ [AssignPopup] Base64字符串为空")
            return nil
        }
        
        // ✅ 安全检查：字符串长度限制（避免内存溢出）
        guard base64String.count < 10_000_000 else { // 约10MB
            print("❌ [AssignPopup] Base64字符串过长，可能损坏: \(base64String.count) 字符")
            return nil
        }
        
        // ✅ 检查是否是Base64格式（可能包含前缀 "data:image/jpeg;base64,"）
        var base64 = base64String
        let originalLength = base64.count
        if base64.hasPrefix("data:image/") {
            if let range = base64.range(of: ",") {
                base64 = String(base64[range.upperBound...])
                print("🔍 [AssignPopup] 移除data:image前缀 - 原始长度: \(originalLength), 处理后长度: \(base64.count)")
            }
        }
        
        // ✅ 解码Base64字符串（添加异常处理）
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            print("❌ [AssignPopup] Base64解码失败 - 字符串长度: \(base64.count), 前100字符: \(String(base64.prefix(100)))")
            return nil
        }
        
        let decodeTime = Date().timeIntervalSince(startTime)
        print("✅ [AssignPopup] Base64解码成功 - 耗时: \(String(format: "%.3f", decodeTime))秒, 数据大小: \(imageData.count) 字节")
        
        // ✅ 安全检查：数据大小限制
        guard imageData.count < 5_000_000 else { // 约5MB
            print("❌ [AssignPopup] 图片数据过大: \(imageData.count) 字节")
            return nil
        }
        
        guard let image = UIImage(data: imageData) else {
            print("❌ [AssignPopup] 无法从数据创建UIImage - 数据大小: \(imageData.count) 字节, 前16字节: \(imageData.prefix(16).map { String(format: "%02x", $0) }.joined())")
            return nil
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // ✅ 验证图片是否有效
        guard image.size.width > 0 && image.size.height > 0 else {
            print("❌ [AssignPopup] 图片尺寸无效: \(image.size)")
            return nil
        }
        
        print("✅ [AssignPopup] 图片创建成功 - 总耗时: \(String(format: "%.3f", totalTime))秒, 尺寸: \(image.size), scale: \(image.scale)")
        return image
    }
}
