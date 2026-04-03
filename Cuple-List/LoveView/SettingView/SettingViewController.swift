//
//  SettingViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import MessageUI
import SnapKit
import ReactiveSwift
import ReactiveCocoa
import StoreKit
import DeviceKit
import Sentry
import RevenueCat
import CocoaLumberjack
import UniformTypeIdentifiers

class SettingViewController: UIViewController,MFMailComposeViewControllerDelegate {
    
    var settingsLabel: UILabel!
    var underSettingsLabel: StrokeShadowLabel!
    var underunderSettingsLabel: StrokeShadowLabel!
    
    private let privacyPolicyURL = "https://docs.couplelist.omicost.cn/privacy"
    private let termsOfUseURL = "https://docs.couplelist.omicost.cn/terms"
    
    var settingLabelImage: UIImageView!
    var settingCupleView: UIView!
    var unlockButton: UIButton!
    /// 中间「Unlock」文案图，订阅后切换为 weeklypro / Yearlypro
    private var unlockMiddleTitleImageView: UIImageView!
    /// 右侧 save、箭头，已订阅时隐藏
    private var unlockTrailingSaveImageView: UIImageView!
    private var unlockTrailingArrowImageView: UIImageView!
    var settingBack: UIImageView!
    var leftAvatarImageView: UIImageView!
    var middleHeartImageView: UIImageView!  // 中间爱心图，未连接时隐藏
    var middleNumberLabel: GradientMaskLabel!
    var undermiddleNumberLabel: StrokeShadowLabel!
    var underundermiddleNumberLabel: StrokeShadowLabel!
    var rightAvatarImageView: UIImageView!
    var UserANameLabel: UILabel!
    var UserBNameLabel: UILabel!
    /// Personal 按钮右侧的「添加伴侣」图标，未连接时显示，已连接时隐藏
    var personalAddPartnerImageView: UIImageView?
    
    // ✅ 防抖机制：避免频繁更新
    private var updateWorkItem: DispatchWorkItem?
    private var lastUpdateTime: Date = Date.distantPast
    private let updateDebounceInterval: TimeInterval = 0.5 // ✅ 减少防抖时间，避免延迟太久
    // ✅ 记录上次头像URL，只在真正变化时才刷新
    private var lastLeftAvatarURL: String?
    private var lastRightAvatarURL: String?
    
    // ✅ 头像缓存：记录当前加载的 UUID、头像 URL 和图片（URL 变化时需重新加载）
    private var leftAvatarUUID: String?
    private var rightAvatarUUID: String?
    private var leftAvatarURLWhenCached: String?  // 缓存对应的头像 URL，换头像后失效
    private var rightAvatarURLWhenCached: String?
    private var leftAvatarImage: UIImage?
    private var rightAvatarImage: UIImage?
    private var isUpdatingAvatars = false // 标记是否正在更新头像
    private var lastSetupBackgroundTime: Date = .distantPast
    private let setupBackgroundCooldown: TimeInterval = 0.35 // 短时防抖，避免重复执行
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        
        // 监听用户数据更新通知（名字、性别等，不包含头像）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDataDidUpdate),
            name: UserManger.dataDidUpdateNotification,
            object: nil
        )
        // ✅ 仅在用户修改头像时刷新设置页头像
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(avatarDidUpdate),
            name: UserManger.avatarDidUpdateNotification,
            object: nil
        )
        // ✅ 监听链接/断开链接通知，重连或断开后立即刷新「是否已连接」状态，避免仍显示未连接
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(linkStatusDidChange),
            name: NSNotification.Name("CoupleDidLinkNotification"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(linkStatusDidChange),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionStatusDidChange),
            name: .NBUserSubscriptionStatusDidChange,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUnlockSubscriptionRowUI()
        // ✅ 优化：延迟加载，避免阻塞页面切换动画
        // ✅ 使用防抖机制，避免频繁调用
        updateWorkItem?.cancel()
        updateWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.isViewLoaded, self.view.window != nil else { return }
            self.setupBackgroundAndAvatars()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: updateWorkItem!)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ✅ 移除 viewDidAppear 中的重复调用，避免与 viewWillAppear 冲突
        // ✅ 如果 viewWillAppear 的延迟任务还没执行，这里再执行一次作为兜底
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, self.isViewLoaded, self.view.window != nil else { return }
            // ✅ 检查是否已经更新过（通过检查背景图片是否已设置）
            if self.settingBack.image == nil && self.settingBack.backgroundColor == .clear {
                self.setupBackgroundAndAvatars()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // ✅ 取消待执行的更新任务
        updateWorkItem?.cancel()
    }
    
    /// 链接成功或断开链接时调用，立即刷新设置页的头像/背景/连接状态
    @objc private func linkStatusDidChange() {
        lastSetupBackgroundTime = .distantPast
        DispatchQueue.main.async { [weak self] in
            self?.setupBackgroundAndAvatars()
        }
    }
    
    /// 仅在用户修改头像时刷新设置页头像
    @objc private func avatarDidUpdate() {
        updateWorkItem?.cancel()
        lastSetupBackgroundTime = .distantPast
        leftAvatarImage = nil
        leftAvatarURLWhenCached = nil
        rightAvatarImage = nil
        rightAvatarURLWhenCached = nil
        lastUpdateTime = Date()
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        lastLeftAvatarURL = currentUser?.avatarImageURL
        lastRightAvatarURL = partnerUser?.avatarImageURL
        setupBackgroundAndAvatars()
    }
    
    @objc private func userDataDidUpdate() {
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let currentAvatarURL = currentUser?.avatarImageURL
        let partnerAvatarURL = partnerUser?.avatarImageURL
        // ✅ 若是头像变更，由 avatarDidUpdate 处理，此处不重复刷新
        if currentAvatarURL != lastLeftAvatarURL || partnerAvatarURL != lastRightAvatarURL {
            return
        }
        
        updateWorkItem?.cancel()
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        if timeSinceLastUpdate < updateDebounceInterval { return }
        
        let delay: TimeInterval = 0
        updateWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lastUpdateTime = Date()
            self.lastLeftAvatarURL = currentAvatarURL
            self.lastRightAvatarURL = partnerAvatarURL
            self.setupBackgroundAndAvatars()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: updateWorkItem!)
    }
    
    func setUI() {
        // 背景渐变
        view.backgroundColor = .white
        
        let gradientView = ViewGradientView()
        view.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 设置标题图片
        underunderSettingsLabel = StrokeShadowLabel()
        underunderSettingsLabel.text = "Settings"
        underunderSettingsLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderSettingsLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderSettingsLabel.shadowBlurRadius = 1.0
//        underunderdayLabel.letterSpacing = 16.0
        underunderSettingsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        view.addSubview(underunderSettingsLabel)
        underunderSettingsLabel.snp.makeConstraints { make in
            make.left.equalTo(17)
            make.topMargin.equalTo(21)
        }
        
        underSettingsLabel = StrokeShadowLabel()
        underSettingsLabel.text = "Settings"
        underSettingsLabel.shadowColor = UIColor.black.withAlphaComponent(0.01)
        underSettingsLabel.shadowOffset = CGSize(width: 0, height: 2)
        underSettingsLabel.shadowBlurRadius = 4.0
//        underdayLabel.letterSpacing = 16.0
        underSettingsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        view.addSubview(underSettingsLabel)
        underSettingsLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderSettingsLabel)
        }
        
        settingsLabel = UILabel()
        settingsLabel.text = "Settings"
        settingsLabel.textColor = .color(hexString: "#322D3A")
        settingsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        view.addSubview(settingsLabel)
        
        settingsLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderSettingsLabel)
        }
        
        // 主容器视图
        settingCupleView = UIView()
        settingCupleView.backgroundColor = .clear
        settingCupleView.layer.cornerRadius = 22
        settingCupleView.clipsToBounds = true
        settingCupleView.layer.borderWidth = 4
        settingCupleView.layer.borderColor = UIColor.white.cgColor
        view.addSubview(settingCupleView)
        settingCupleView.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalToSuperview().multipliedBy(177.0 / 812.0)
            make.centerX.equalToSuperview()
            make.top.equalTo(underunderSettingsLabel.snp.bottom).offset(19)
        }
        
        // 背景图片（稍后根据连接状态和性别动态设置）
        settingBack = UIImageView()
        settingBack.contentMode = .scaleAspectFill  // ✅ 修复：设置内容模式，确保图片正确显示
        settingBack.clipsToBounds = true  // ✅ 修复：确保图片不会超出边界
        settingCupleView.addSubview(settingBack)
        settingBack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 左侧头像（女性或自己的头像）
        leftAvatarImageView = UIImageView()
        leftAvatarImageView.contentMode = .scaleAspectFill
        leftAvatarImageView.layer.cornerRadius = 30
        leftAvatarImageView.clipsToBounds = true
        leftAvatarImageView.backgroundColor = .clear
        // ✅ 确保图片正确渲染
        leftAvatarImageView.layer.masksToBounds = true
        settingCupleView.addSubview(leftAvatarImageView)
        leftAvatarImageView.snp.makeConstraints { make in
            make.left.equalTo(47)
            make.top.equalTo(18)
            make.width.equalToSuperview().multipliedBy(66.0 / 335.0)
            make.height.equalTo(leftAvatarImageView.snp.width)
        }
        
        UserANameLabel = UILabel()
        UserANameLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        UserANameLabel.textColor = .color(hexString: "#322D3A")
        UserANameLabel.isUserInteractionEnabled = false
        settingCupleView.addSubview(UserANameLabel)
        UserANameLabel.snp.makeConstraints { make in
            make.centerX.equalTo(leftAvatarImageView)
            make.top.equalTo(leftAvatarImageView.snp.bottom).offset(6)
        }
        
        middleHeartImageView = UIImageView(image: .hzleftfemale)
        settingCupleView.addSubview(middleHeartImageView)
        middleHeartImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(leftAvatarImageView)
            make.height.equalToSuperview().multipliedBy(38.0 / 177.0)
            make.width.equalToSuperview().multipliedBy(107.0 / 335.0)
        }
        
        // 右侧头像（男性或对方的头像）
        rightAvatarImageView = UIImageView()
        rightAvatarImageView.contentMode = .scaleAspectFill
        rightAvatarImageView.layer.cornerRadius = 30
        rightAvatarImageView.clipsToBounds = true
        rightAvatarImageView.backgroundColor = .clear
        // ✅ 确保图片正确渲染
        rightAvatarImageView.layer.masksToBounds = true
        settingCupleView.addSubview(rightAvatarImageView)
        rightAvatarImageView.snp.makeConstraints { make in
            make.right.equalTo(-47)
            make.top.equalTo(18)
            make.width.equalToSuperview().multipliedBy(66.0 / 335.0)
            make.height.equalTo(rightAvatarImageView.snp.width)
        }
        
        UserBNameLabel = UILabel()
        UserBNameLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        UserBNameLabel.textColor = .color(hexString: "#322D3A")
        UserBNameLabel.isUserInteractionEnabled = false
        settingCupleView.addSubview(UserBNameLabel)
        UserBNameLabel.snp.makeConstraints { make in
            make.centerX.equalTo(rightAvatarImageView)
            make.top.equalTo(leftAvatarImageView.snp.bottom).offset(6)
        }
        
        let unlockButtonView = SettingBorderGradientView()
        unlockButtonView.layer.cornerRadius = 15
        settingCupleView.addSubview(unlockButtonView)
        unlockButtonView.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(311.0 / 335.0)
            make.centerX.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(42.0 / 177.0)
            make.bottom.equalTo(-12)
        }
        
        unlockButton = UIButton()
        unlockButton.addTarget(self, action: #selector(unlockButtonTapped), for: .touchUpInside)
        unlockButtonView.addSubview(unlockButton)
        unlockButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let unImage = UIImageView(image: .vipButton)
        unImage.isUserInteractionEnabled = false
        unlockButtonView.addSubview(unImage)
        unImage.snp.makeConstraints { make in
            make.left.equalTo(6)
            make.centerY.equalToSuperview()
        }
        
        unlockMiddleTitleImageView = UIImageView(image: .unlockLabel)
        unlockMiddleTitleImageView.isUserInteractionEnabled = false
        unlockButtonView.addSubview(unlockMiddleTitleImageView)
        unlockMiddleTitleImageView.snp.makeConstraints { make in
            make.left.equalTo(unImage.snp.right).offset(-6)
            make.centerY.equalToSuperview()
        }
        
        unlockTrailingArrowImageView = UIImageView(image: .settingArrow)
        unlockTrailingArrowImageView.isUserInteractionEnabled = false
        unlockButtonView.addSubview(unlockTrailingArrowImageView)
        unlockTrailingArrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(-5)
        }
        
        unlockTrailingSaveImageView = UIImageView(image: .saveLabel)
        unlockTrailingSaveImageView.isUserInteractionEnabled = false
        unlockButtonView.addSubview(unlockTrailingSaveImageView)
        unlockTrailingSaveImageView.snp.makeConstraints { make in
            make.right.equalTo(unlockTrailingArrowImageView.snp.left).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        updateUnlockSubscriptionRowUI()
        
        // 按钮垂直StackView（添加到view，在主容器下方）
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.alignment = .center
        buttonStackView.spacing = 12
        buttonStackView.distribution = .equalSpacing
        view.addSubview(buttonStackView)
        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(settingCupleView.snp.bottom).offset(20)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.centerX.equalToSuperview()
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
        }
        
        // 数据（修正重复标题，用可选绑定避免强制解包）
        let buttonData: [(imageName: String, title: String)] = [
            ("icon1", "Personal Info"),
            ("icon2", "Share with friends"),
            ("icon3", "Feedback"),
            ("icon4", "Privacy Policy"),
            ("icon5", "Terms of Service")
        ]
        
        // 循环创建按钮
        for (index, data) in buttonData.enumerated() {
            let rectangle = BorderGradientView()
            rectangle.backgroundColor = .white
            rectangle.layer.cornerRadius = 18
            buttonStackView.addArrangedSubview(rectangle)
            rectangle.snp.makeConstraints{ make in
                make.height.equalTo(52)
                make.width.equalToSuperview()
            }
            
            let imageView = UIImageView()
            if data.imageName.hasPrefix("sf:") {
                let sysName = String(data.imageName.dropFirst(3))
                let conf = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
                imageView.image = UIImage(systemName: sysName, withConfiguration: conf)
                imageView.tintColor = .color(hexString: "#111111")
            } else if let image = UIImage(named: data.imageName) {
                imageView.image = image
            } else {
                imageView.image = UIImage(systemName: "questionmark.circle")
            }
            imageView.contentMode = .scaleAspectFit
            rectangle.addSubview(imageView)
            imageView.snp.makeConstraints{ make in
                make.centerY.equalToSuperview()
                make.left.equalTo(14)
//                make.width.height.equalTo(24)
            }
            
            let label = UILabel()
            label.text = data.title
            label.textColor = .black
            label.textAlignment = .left
            label.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
            if label.font == nil {
                label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            }
            rectangle.addSubview(label)
            label.snp.makeConstraints{ make in
                make.left.equalTo(imageView.snp.right).offset(8)
                make.centerY.equalTo(imageView)
                make.right.lessThanOrEqualTo(rectangle.snp.right).offset(-40)
            }
            
            let arrow = UIImageView()
            if let arrowImage = UIImage(named: "settingArrow") {
                arrow.image = arrowImage
            } else {
                arrow.image = UIImage(systemName: "chevron.right")
            }
            arrow.contentMode = .scaleAspectFit
            rectangle.addSubview(arrow)
            arrow.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.right.equalTo(-14)
                make.width.height.equalTo(16)
            }
            
            // Personal 按钮右侧：未连接时显示 addpartner 图标，已连接时隐藏
            if index == 0 {
                let addPartnerIv = UIImageView()
                addPartnerIv.image = UIImage(named: "addpartner")
//                addPartnerIv.contentMode = .scaleAspectFit
                addPartnerIv.isHidden = true // 默认隐藏，由 setupBackgroundAndAvatars 根据连接状态更新
                rectangle.addSubview(addPartnerIv)
                addPartnerIv.snp.makeConstraints { make in
                    make.centerY.equalToSuperview()
                    make.right.equalTo(arrow.snp.left).offset(-5)
//                    make.width.equalTo(80)
//                    make.height.equalTo(30)
                }
                personalAddPartnerImageView = addPartnerIv
            }
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(rectangleTapped(sender:)))
            rectangle.addGestureRecognizer(tapGesture)
            rectangle.isUserInteractionEnabled = true
            rectangle.tag = index
        }
    }
    
    @objc func rectangleTapped(sender: UITapGestureRecognizer) {
        guard let tappedRectangle = sender.view else { return }
        let buttonIndex = tappedRectangle.tag
        
        switch buttonIndex {
        case 0:
            restore()
        case 1:
            shareWithFriends()
        case 2:
            sendFeedback()
        case 3:
            showPrivacyPolicy()
        case 4:
            showTermsOfService()
        default:
            break
        }
    }
    
    func restore() {
        restorePurchaseData()
    }
    
    /// 订阅/VIP 状态变化（购买、恢复、过期）后刷新解锁条
    @objc private func subscriptionStatusDidChange() {
        updateUnlockSubscriptionRowUI()
    }
    
    /// 已订阅：中间图为 weeklypro / Yearlypro（按产品 ID），隐藏右侧两图，且不可点击；未订阅可点击进入订阅页。
    private func updateUnlockSubscriptionRowUI() {
        guard let mid = unlockMiddleTitleImageView,
              let saveIv = unlockTrailingSaveImageView,
              let arrowIv = unlockTrailingArrowImageView else { return }
        
        let subscribed = NBUserVipStatusManager.shard.getVipStatus()
        guard subscribed else {
            mid.image = .unlockLabel
            saveIv.isHidden = false
            arrowIv.isHidden = false
            unlockButton.isUserInteractionEnabled = true
            return
        }
        
        let subId = UserDefaults.standard.string(forKey: UserDefaultsKey.SubscriptionId) ?? ""
        let store = NBNewStoreManager.shard
        switch subId {
        case store.weekProductId:
            mid.image = UIImage(named: "weeklypro")
        case store.yearProductId:
            mid.image = UIImage(named: "Yearlypro")
        case store.monthProductId:
            mid.image = UIImage(named: "Yearlypro")
        default:
            mid.image = .unlockLabel
        }
        saveIv.isHidden = true
        arrowIv.isHidden = true
        unlockButton.isUserInteractionEnabled = false
    }
    
    @objc func unlockButtonTapped() {
        let proVc = VipUIViewController()
        proVc.modalPresentationStyle = .fullScreen
        self.present(proVc, animated: true)
    }
    
    func shareWithFriends() {
        let content = "https://itunes.apple.com/app/6756169335"
        let activityVC = UIActivityViewController(activityItems: [content], applicationActivities: nil)
        present(activityVC, animated: true, completion: nil)
    }
    
    func sendFeedback() {
        let mailAddress = "feedback@omicost.cn"
        if MFMailComposeViewController.canSendMail() {
            guard let infoDictionary = Bundle.main.infoDictionary,
                  let name = infoDictionary["CFBundleName"] as? String,
                  let currentVersionStr = infoDictionary["CFBundleShortVersionString"] as? String else {
                print("❌ 无法获取 Bundle 信息")
                return
            }
            let deviceInfo = String(format: "(%@ %@ on %@ running with %@ %@,device %@)", name, currentVersionStr, Device.current.description, Device.current.systemName ?? "",Device.current.systemVersion ?? "" , Device.identifier)
            
            let bodyHtml = String(format: "<br><br><br><div style=\"color: gray;font-size: 12;\">%@</div><br><br><br>", arguments: [deviceInfo])
            
            let mailVC = MFMailComposeViewController()
            mailVC.mailComposeDelegate = self
            mailVC.setToRecipients([mailAddress])
            mailVC.setSubject("Stone Hunter")
            mailVC.setMessageBody(bodyHtml, isHTML: true)
            self.present(mailVC, animated: true, completion: nil)
        } else {
            let mailStr = "mailto:" + mailAddress
            UIApplication.shared.open(URL(string: mailStr)!, options: [:], completionHandler: nil)
        }
    }
    
    func showPrivacyPolicy() {
        BaseWebController.presentAsSheet(from: self, urlString: privacyPolicyURL)
    }
    
    func showTermsOfService() {
        BaseWebController.presentAsSheet(from: self, urlString: termsOfUseURL)
    }
    
    func restorePurchaseData() {
        self.navigationController?.pushViewController(UserAvatarViewController(), animated: true)
    }
    
    // ✅ 修复：补全语法错误（原代码未定义firebaseStartTime、闭包未闭合）
    private func loadUserAvatarsAndNames() {
        let currentUUID = CoupleStatusManager.getUserUniqueUUID()
        print("  - 当前UUID: \(currentUUID)")
        
        let coupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
        let firebaseStartTime = Date() // ✅ 新增：定义缺失的变量
        
        let db = Firestore.firestore()
        db.collection("users").document(currentUUID).getDocument { [weak self] snapshot, error in
            let firebaseDuration = Date().timeIntervalSince(firebaseStartTime)
            print("🔍 [SettingVC] Firebase请求完成 - 耗时: \(String(format: "%.3f", firebaseDuration))秒")
            
            guard let self = self else {
                print("⚠️ [SettingVC] self已释放，取消Firebase同步处理")
                return
            }
            // 可在这里添加Firebase同步逻辑（和AssignPopup一致）
            if let error = error {
                print("❌ [SettingVC] Firebase同步失败: \(error.localizedDescription)")
                return
            }
            // 同步成功后更新UI
            self.setupBackgroundAndAvatars()
        }
    }
    
    // MARK: - 设置背景、头像和名字（核心修改：新增名字设置逻辑）
    private func setupBackgroundAndAvatars() {
        guard let settingBack = settingBack,
              let leftAvatarImageView = leftAvatarImageView,
              let middleHeartImageView = middleHeartImageView,
              let rightAvatarImageView = rightAvatarImageView,
              let userANameLabel = UserANameLabel, // ✅ 新增：强引用名字Label
              let userBNameLabel = UserBNameLabel else {
            print("⚠️ SettingViewController: UI 还未初始化，跳过背景和头像设置")
            return
        }
        
        // ✅ 防止重复更新：如果正在更新，直接返回
        guard !isUpdatingAvatars else { return }
        // ✅ 短时防抖：避免 viewWillAppear/viewDidAppear/通知 等多次触发导致重复执行
        let now = Date()
        guard now.timeIntervalSince(lastSetupBackgroundTime) >= setupBackgroundCooldown else { return }
        lastSetupBackgroundTime = now
        isUpdatingAvatars = true
        defer { isUpdatingAvatars = false } // ✅ 确保总是重置标记
        
        let isLinked = CoupleStatusManager.shared.isUserLinked
        // Personal 按钮右侧：未连接显示 addpartner 图标，已连接则隐藏
        personalAddPartnerImageView?.isHidden = isLinked
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        let currentUUID = UserManger.manager.currentUserUUID
        // ✅ 新增：获取情侣双方名字（复用AssignPopup逻辑）
        let coupleInfo = UserManger.manager.getCoupleNamesAndAvatars()
        let myName = coupleInfo.myName
        let partnerName = coupleInfo.partnerName
        // ✅ 新增：名字兜底（空/未知时显示默认名，和AssignPopup一致）
        let showMyName = myName.isEmpty || myName == "未知" ? "Waves" : myName
        let showPartnerName = partnerName.isEmpty || partnerName == "未知" ? "Momo" : partnerName

        // 获取当前用户和伴侣的性别
        let currentUserModel = UserManger.manager.getUserModelByUUID(currentUUID)
        let currentGender = currentUserModel?.gender
        let partnerGender = partnerUser?.gender
        
        // 判断性别的辅助函数
        func isFemale(_ gender: String?) -> Bool {
            guard let gender = gender else { return false }
            let lowercased = gender.lowercased().trimmingCharacters(in: .whitespaces)
            return lowercased == "female" || lowercased == "女性" || lowercased == "女"
        }
        
        func isMale(_ gender: String?) -> Bool {
            guard let gender = gender else { return false }
            let lowercased = gender.lowercased().trimmingCharacters(in: .whitespaces)
            return lowercased == "male" || lowercased == "男性" || lowercased == "男"
        }
        
        if isLinked && currentUser != nil && partnerUser != nil {
            // 已连接且有伴侣：左侧永远是自己，右侧永远是对方；根据性别组合设置背景和爱心
            let currentIsFemale = isFemale(currentGender)
            let currentIsMale = isMale(currentGender)
            let partnerIsFemale = isFemale(partnerGender)
            let partnerIsMale = isMale(partnerGender)
            
            middleHeartImageView.isHidden = false
            leftAvatarImageView.isHidden = false
            rightAvatarImageView.isHidden = false
            userANameLabel.isHidden = false
            userBNameLabel.isHidden = false
            // 左侧头像在已连接时靠左
            leftAvatarImageView.snp.remakeConstraints { make in
                make.left.equalTo(47)
                make.top.equalTo(18)
                make.width.equalToSuperview().multipliedBy(66.0 / 335.0)
                make.height.equalTo(leftAvatarImageView.snp.width)
            }
            settingCupleView.layoutIfNeeded()

            // 左侧永远是自己，右侧永远是对方
            loadAvatarForUser(uuid: currentUUID, imageView: leftAvatarImageView)
            if let partnerUUID = partnerUser?.id {
                loadAvatarForUser(uuid: partnerUUID, imageView: rightAvatarImageView)
            }
            userANameLabel.text = showMyName
            userBNameLabel.text = showPartnerName

            // 根据性别组合设置背景和爱心：自己男对方女→setleftmale/hzleftmale；自己男对方男→setman/hzmale；自己女对方男→setleftfemale/hzleftfemale；自己女对方女→setwoman/hzfemale
            if currentIsMale && partnerIsFemale {
                settingBack.image = UIImage(named: "setleftmale")
                settingBack.backgroundColor = .clear
                middleHeartImageView.image = UIImage(named: "hzleftmale")
            } else if currentIsMale && partnerIsMale {
                let manImg = UIImage(named: "setman")
                settingBack.image = manImg ?? nil
                settingBack.backgroundColor = manImg == nil ? .color(hexString: "#E3F2FD") : .clear
                middleHeartImageView.image = UIImage(named: "hzmale")
            } else if currentIsFemale && partnerIsMale {
                settingBack.image = UIImage(named: "setleftfemale")
                settingBack.backgroundColor = .clear
                middleHeartImageView.image = UIImage(named: "hzleftfemale")
            } else if currentIsFemale && partnerIsFemale {
                settingBack.image = UIImage(named: "setwoman")
                settingBack.backgroundColor = .clear
                middleHeartImageView.image = UIImage(named: "hzfemale")
            } else {
                // 性别未知时的兜底
                settingBack.image = UIImage(named: "setman")
                settingBack.backgroundColor = .clear
                middleHeartImageView.image = UIImage(named: "hzmale")
            }
        } else {
            // 未连接或无伴侣：隐藏中间爱心，只显示自己头像居中
            middleHeartImageView.isHidden = true
            leftAvatarImageView.isHidden = false
            rightAvatarImageView.isHidden = true
            userANameLabel.isHidden = false  // ✅ 新增：显示左侧自己的名字
            userBNameLabel.isHidden = true   // ✅ 新增：隐藏右侧伴侣名字
            // 自己头像居中显示
            leftAvatarImageView.snp.remakeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(18)
                make.width.equalToSuperview().multipliedBy(66.0 / 335.0)
                make.height.equalTo(leftAvatarImageView.snp.width)
            }
            userANameLabel.snp.remakeConstraints { make in
                make.centerX.equalTo(leftAvatarImageView)
                make.top.equalTo(leftAvatarImageView.snp.bottom).offset(6)
            }

            // 加载自己头像
            loadAvatarForUser(uuid: currentUUID, imageView: leftAvatarImageView)
            settingCupleView.layoutIfNeeded()
            // ✅ 新增：设置自己的名字（左侧）
            userANameLabel.text = showMyName

            // 根据性别设置背景
            if let gender = currentGender {
                if isFemale(gender) {
                    settingBack.image = UIImage(named: "setwoman")
                    settingBack.backgroundColor = .clear
                } else if isMale(gender) {
                    let manImage = UIImage(named: "setman")
                    settingBack.image = manImage ?? nil
                    settingBack.backgroundColor = manImage == nil ? .color(hexString: "#E3F2FD") : .clear
                } else {
                    settingBack.image = nil
                    settingBack.backgroundColor = .white
                }
            } else {
                settingBack.image = nil
                settingBack.backgroundColor = .white
            }
        }
    }
    
    /// 无头像时根据性别返回默认图资源名（与 UserAvatar/SetView 一致）
    private func defaultAvatarImageName(for gender: String?) -> String {
        guard let g = gender, !g.isEmpty else { return "userText" }
        let lower = g.lowercased().trimmingCharacters(in: .whitespaces)
        if lower == "male" || lower == "男性" || lower == "男" { return "maleImageback" }
        if lower == "female" || lower == "女性" || lower == "女" { return "femaleImageback" }
        return "userText"
    }

    /// 默认头像不显示阴影：与 AddPopup 的 clearAssignStatusAvatarShadow 一致，避免与旧自定义头像阴影重叠
    private func clearAvatarShadow(on imageView: UIImageView) {
        imageView.layer.shadowOpacity = 0
        if let sub = imageView.layer.sublayers?.first(where: { $0.name == "avatarShadowSecondLayer" }) {
            sub.removeFromSuperlayer()
        } else if let first = imageView.layer.sublayers?.first {
            first.removeFromSuperlayer()
        }
    }

    // MARK: - 头像抠图+白边显示样式（与用户页、积分页一致，含统一阴影）
    private func applyAvatarCutoutStyle(to imageView: UIImageView) {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = false
        imageView.layer.cornerRadius = 0
        imageView.applyAvatarCutoutShadow()
    }
    
    // MARK: - 加载用户头像（优化：添加缓存机制，头像 URL 变化时强制重新加载；无头像时按性别显示默认图）
    private func loadAvatarForUser(uuid: String, imageView: UIImageView) {
        let isLeftAvatar = (imageView == leftAvatarImageView)
        let cachedUUID = isLeftAvatar ? leftAvatarUUID : rightAvatarUUID
        let cachedURL = isLeftAvatar ? leftAvatarURLWhenCached : rightAvatarURLWhenCached
        let cachedImage = isLeftAvatar ? leftAvatarImage : rightAvatarImage
        let userGender = UserManger.manager.getUserModelByUUID(uuid)?.gender
        let defaultImageName = defaultAvatarImageName(for: userGender)

        // ✅ 当前该用户最新的头像 URL（换头像后与缓存 URL 不一致则必须重新加载）
        let currentAvatarURL = UserManger.manager.getUserModelByUUID(uuid)?.avatarImageURL ?? ""
        
        // ✅ 只有 UUID 相同、头像 URL 未变、且已有有效缓存图时才跳过加载
        if cachedUUID == uuid,
           !currentAvatarURL.isEmpty,
           currentAvatarURL == cachedURL,
           let cached = cachedImage, cached != UIImage(named: "maleImageback") && cached != UIImage(named: "femaleImageback") {
            if imageView.image != cached {
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        self.view.layoutIfNeeded()
                        imageView.image = cached
                        self.applyAvatarCutoutStyle(to: imageView)
                    }
                }
            }
            return
        }
        
        // ✅ 更新缓存的 UUID（URL 变化时上面不会命中，会走到这里重新加载）
        if isLeftAvatar {
            leftAvatarUUID = uuid
        } else {
            rightAvatarUUID = uuid
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 优先从 CoreData 获取头像
            if let userModel = UserManger.manager.getUserModelByUUID(uuid),
               let avatarURL = userModel.avatarImageURL, !avatarURL.isEmpty {
                if let image = self.imageFromBase64String(avatarURL) {
                    if isLeftAvatar { self.leftAvatarURLWhenCached = avatarURL } else { self.rightAvatarURLWhenCached = avatarURL }
                    ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 10, cacheKey: avatarURL) { [weak self] processedImage in
                        guard let self = self else { return }
                        let finalImage = processedImage ?? image
                        if isLeftAvatar {
                            self.leftAvatarImage = finalImage
                        } else {
                            self.rightAvatarImage = finalImage
                        }
                        DispatchQueue.main.async { [weak imageView] in
                            guard let imageView = imageView else { return }
                            let currentUUID = isLeftAvatar ? self.leftAvatarUUID : self.rightAvatarUUID
                            if currentUUID == uuid {
                                UIView.performWithoutAnimation {
                                    self.view.layoutIfNeeded()
                                    imageView.image = finalImage
                                    self.applyAvatarCutoutStyle(to: imageView)
                                }
                            }
                        }
                    }
                    return
                }
            }
            
            // CoreData 无数据，从 Firebase 加载
            let db = Firestore.firestore()
            db.collection("users").document(uuid).getDocument { [weak self, weak imageView] snapshot, error in
                guard let self = self, let imageView = imageView else { return }
                
                // ✅ 再次检查UUID是否仍然匹配
                let currentUUID = isLeftAvatar ? self.leftAvatarUUID : self.rightAvatarUUID
                guard currentUUID == uuid else {
                    print("⚠️ SettingViewController: UUID已改变，取消加载 UUID=\(uuid)")
                    return
                }
                
                if let error = error {
                    print("⚠️ SettingViewController: 从Firebase加载头像失败: \(error.localizedDescription)")
                    let defaultImage = UIImage(named: defaultImageName)
                    if isLeftAvatar {
                        self.leftAvatarImage = defaultImage
                        self.leftAvatarURLWhenCached = nil
                    } else {
                        self.rightAvatarImage = defaultImage
                        self.rightAvatarURLWhenCached = nil
                    }
                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            let currentUUID = isLeftAvatar ? self.leftAvatarUUID : self.rightAvatarUUID
                            if currentUUID == uuid {
                                imageView.image = defaultImage
                                self.clearAvatarShadow(on: imageView)
                            }
                        }
                    }
                    return
                }
                
                guard let data = snapshot?.data(),
                      let avatarURL = data["avatarImageURL"] as? String, !avatarURL.isEmpty else {
                    let defaultImage = UIImage(named: defaultImageName)
                    if isLeftAvatar {
                        self.leftAvatarImage = defaultImage
                        self.leftAvatarURLWhenCached = nil
                    } else {
                        self.rightAvatarImage = defaultImage
                        self.rightAvatarURLWhenCached = nil
                    }
                    DispatchQueue.main.async {
                        UIView.performWithoutAnimation {
                            let currentUUID = isLeftAvatar ? self.leftAvatarUUID : self.rightAvatarUUID
                            if currentUUID == uuid {
                                imageView.image = defaultImage
                                self.clearAvatarShadow(on: imageView)
                            }
                        }
                    }
                    return
                }
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    if let image = self.imageFromBase64String(avatarURL) {
                        if isLeftAvatar { self.leftAvatarURLWhenCached = avatarURL } else { self.rightAvatarURLWhenCached = avatarURL }
                        ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 10, cacheKey: avatarURL) { [weak self] processedImage in
                            guard let self = self else { return }
                            let finalImage = processedImage ?? image
                            if isLeftAvatar {
                                self.leftAvatarImage = finalImage
                            } else {
                                self.rightAvatarImage = finalImage
                            }
                            DispatchQueue.main.async { [weak imageView] in
                                guard let imageView = imageView else { return }
                                let currentUUID = isLeftAvatar ? self.leftAvatarUUID : self.rightAvatarUUID
                                if currentUUID == uuid {
                                    UIView.performWithoutAnimation {
                                        self.view.layoutIfNeeded()
                                        imageView.image = finalImage
                                        self.applyAvatarCutoutStyle(to: imageView)
                                    }
                                }
                            }
                        }
                    } else {
                        let defaultImage = UIImage(named: defaultImageName)
                        if isLeftAvatar {
                            self.leftAvatarImage = defaultImage
                            self.leftAvatarURLWhenCached = nil
                        } else {
                            self.rightAvatarImage = defaultImage
                            self.rightAvatarURLWhenCached = nil
                        }
                        DispatchQueue.main.async { [weak imageView] in
                            guard let imageView = imageView else { return }
                            UIView.performWithoutAnimation {
                                let currentUUID = isLeftAvatar ? self.leftAvatarUUID : self.rightAvatarUUID
                                if currentUUID == uuid {
                                    imageView.image = defaultImage
                                    self.clearAvatarShadow(on: imageView)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Base64 图片解码
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        guard !base64String.isEmpty else { return nil }
        
        var base64 = base64String
        if base64.hasPrefix("data:image/") {
            if let range = base64.range(of: ",") {
                base64 = String(base64[range.upperBound...])
            }
        }
        
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        
        return UIImage(data: imageData)
    }
    
    // MARK: ✅ 导出日志功能
    func exportLogs() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var logFilePaths: [String] = []
            let allLoggers = DDLog.allLoggers
            for logger in allLoggers {
                if let fileLogger = logger as? DDFileLogger {
                    let manager = fileLogger.logFileManager
                    if let paths = manager.sortedLogFilePaths as? [String] {
                        logFilePaths.append(contentsOf: paths)
                    }
                    if let currentLogFile = fileLogger.currentLogFileInfo?.filePath, !logFilePaths.contains(currentLogFile) {
                        logFilePaths.append(currentLogFile)
                    }
                }
            }
            
            let possibleDirectories = [
                FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs"),
                FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs"),
                FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs"),
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs")
            ]
            
            for directory in possibleDirectories {
                if let dir = directory, FileManager.default.fileExists(atPath: dir.path) {
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                        let foundFiles = files
                            .filter { $0.hasSuffix(".log") || $0.hasSuffix(".txt") }
                            .map { dir.appendingPathComponent($0).path }
                            .filter { !logFilePaths.contains($0) }
                        logFilePaths.append(contentsOf: foundFiles)
                    }
                }
            }
            
            logFilePaths = Array(Set(logFilePaths)).sorted()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if logFilePaths.isEmpty {
                    self.createFallbackLog()
                    return
                }
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    
                    var allLogs = "=== App Logs Export ===\n"
                    allLogs += "Export Time: \(Date())\n"
                    allLogs += "Device: \(UIDevice.current.model) \(UIDevice.current.systemVersion)\n"
                    allLogs += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
                    allLogs += "Build Version: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")\n"
                    allLogs += "User UUID: \(CoupleStatusManager.getUserUniqueUUID())\n"
                    allLogs += "Couple ID: \(CoupleStatusManager.getPartnerId() ?? "Not linked")\n"
                    allLogs += "================================\n\n"
                    allLogs += "Found \(logFilePaths.count) log file(s):\n\n"
                    
                    var totalSize: Int64 = 0
                    var successCount = 0
                    
                    for logFilePath in logFilePaths {
                        if FileManager.default.fileExists(atPath: logFilePath) {
                            if let attributes = try? FileManager.default.attributesOfItem(atPath: logFilePath),
                               let fileSize = attributes[.size] as? Int64 {
                                totalSize += fileSize
                            }
                            
                            var logContent: String? = nil
                            var readError: String? = nil
                            
                            if let fileHandle = FileHandle(forReadingAtPath: logFilePath) {
                                defer { fileHandle.closeFile() }
                                do {
                                    let data = fileHandle.readDataToEndOfFile()
                                    let encodings: [String.Encoding] = [.utf8, .utf16, .ascii, .windowsCP1252]
                                    for encoding in encodings {
                                        if let content = String(data: data, encoding: encoding) {
                                            logContent = content
                                            break
                                        }
                                    }
                                    
                                    if logContent == nil {
                                        if let utf8Content = String(data: data, encoding: .utf8) {
                                            logContent = utf8Content
                                            readError = "使用UTF-8读取（可能包含无效字符）"
                                        } else {
                                            let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
                                            logContent = "⚠️ 无法解析为文本，原始数据（前1000字节）:\n\(String(hexString.prefix(1000)))"
                                            readError = "无法使用任何编码解析文件"
                                        }
                                    }
                                } catch {
                                    readError = "读取文件时出错: \(error.localizedDescription)"
                                }
                            } else {
                                readError = "无法打开文件（可能被锁定）"
                            }
                            
                            if logContent == nil {
                                let encodings: [String.Encoding] = [.utf8, .utf16, .ascii]
                                for encoding in encodings {
                                    if let content = try? String(contentsOfFile: logFilePath, encoding: encoding) {
                                        logContent = content
                                        break
                                    }
                                }
                            }
                            
                            if let content = logContent, !content.isEmpty {
                                allLogs += "=== \(URL(fileURLWithPath: logFilePath).lastPathComponent) ===\n"
                                allLogs += "File Size: \(content.count) characters\n"
                                allLogs += "File Path: \(logFilePath)\n"
                                if let error = readError {
                                    allLogs += "⚠️ 警告: \(error)\n"
                                }
                                allLogs += "--- Content Start ---\n"
                                allLogs += content
                                allLogs += "\n--- Content End ---\n\n"
                                successCount += 1
                            } else {
                                allLogs += "=== \(URL(fileURLWithPath: logFilePath).lastPathComponent) ===\n"
                                allLogs += "File Path: \(logFilePath)\n"
                                allLogs += "⚠️ 无法读取文件内容"
                                if let error = readError {
                                    allLogs += ": \(error)"
                                }
                                allLogs += "\n\n"
                            }
                        }
                    }
                    
                    allLogs += "\n================================\n"
                    allLogs += "Summary: \(successCount)/\(logFilePaths.count) files read successfully\n"
                    allLogs += "Total Size: \(totalSize) bytes\n"
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.shareLogs(allLogs: allLogs)
                    }
                }
            }
        }
    }
    
    private func createFallbackLog() {
        var allLogs = "=== App Logs Export ===\n"
        allLogs += "Export Time: \(Date())\n"
        allLogs += "Device: \(UIDevice.current.model) \(UIDevice.current.systemVersion)\n"
        allLogs += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n"
        allLogs += "Build Version: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")\n"
        allLogs += "User UUID: \(CoupleStatusManager.getUserUniqueUUID())\n"
        allLogs += "Couple ID: \(CoupleStatusManager.getPartnerId() ?? "Not linked")\n"
        allLogs += "Is Linked: \(CoupleStatusManager.shared.isUserLinked)\n"
        
        let (currentUser, partnerUser) = UserManger.manager.getCoupleUsers()
        allLogs += "Current User Name: \(currentUser?.userName ?? "Unknown")\n"
        allLogs += "Partner User Name: \(partnerUser?.userName ?? "Unknown")\n"
        
        allLogs += "================================\n\n"
        allLogs += "Note: No log files found.\n"
        
        shareLogs(allLogs: allLogs)
    }
    
    private func shareLogs(allLogs: String) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let fileName = "app_logs_\(Date().timeIntervalSince1970).txt"
        let fileURL = documentsDir.appendingPathComponent(fileName)
        
        do {
            try allLogs.write(to: fileURL, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            activityVC.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
                if let error = error {
                    print("❌ 分享失败: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.showAlert(content: "分享失败: \(error.localizedDescription)")
                    }
                } else if completed {
                    print("✅ 日志分享成功")
                    DispatchQueue.main.async {
                        self?.showAlert(content: "日志导出成功！")
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
            
            present(activityVC, animated: true)
        } catch {
            print("❌ 创建日志文件失败: \(error.localizedDescription)")
            showAlert(content: "导出日志失败: \(error.localizedDescription)\n\n请检查设备存储空间是否充足。")
        }
    }
}

extension SettingViewController: NBInAppPurchaseProtocol {
    func subscriptionProductsDidReciveSuccess(products: [StoreProduct]) {}
    func subscriptionProductsDidReciveFailure() {}
    func purchasedSuccess(_ needUnsubscribe: Bool) {}
    func purchasedFailure(error: Error?) {}
    func restorePurchaseSuccess() {
        showAlert(content: "Restore Success")
    }
    func restorePurchaseFailure() {
        showAlert(content: "Restore Failure")
    }
    
    func showPurchaseSuccessAlert(_ needUnsubscribe: Bool = false) {
        showAlert(content: "Purchase Success")
    }
    
    func showAlert(content: String, handler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let vc = UIAlertController(title: nil, message: content, preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak vc] _ in
                vc?.dismiss(animated: true, completion: nil)
                handler?()
            }))
            self.present(vc, animated: true, completion: nil)
        }
    }
}
