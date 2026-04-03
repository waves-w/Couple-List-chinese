//
//  CheekBootPageView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class CheekBootPageView: UIViewController {
    // MARK: - UI 组件
    private var backButton: UIButton!
    private var maybeButton: UIButton!
    private var puineImage: UIImageView!
    private var conLabel: UILabel!
    private var shareLabel: UILabel!
    private var invitationField: UIView!
    var invitationLabel: BootGradientMaskLabel!
    var underinvitationLabel: BootStrokeShadowLabel!
    var underunderinvitationLabel: BootStrokeShadowLabel!
    var copyButton: UIButton!
    
    private var partnerIdContainerView: UIView!
    var partnerIdTopLabel: BootGradientMaskLabel!
    var partnerIdMidLabel: BootStrokeShadowLabel!
    var partnerIdBotLabel: BootStrokeShadowLabel!
    private var partnerIdTextField: UITextField!
    private var continueButton: UIButton!
    private var successdeView: UIView!
    private var listenerRegistration: ListenerRegistration?
    private let kIsCoupleLinked = "isCoupleLinked"
    
    // ✅ 键盘输入相关
    private var hiddenTextField: UITextField! // 隐藏的TextField，用于弹出键盘
    private var keyboardInputView: UIView! // 键盘上方的输入视图
    private var codeInputTextField: UITextField! // 输入框（在键盘上方）
    
    // ✅ 新增：标记是否从断开链接弹窗 present 进来的
    var isPresentedFromUnlink: Bool = false
    /// 被动端：监听到对方 isInLinkedState=false 后 present 进来，文案与返回行为与主动 unlink 一致
    var isPresentedFromPartnerUnlink: Bool = false
    // ✅ 点击 Done 收起键盘时，防止触摸落点触发邀请码区域再次弹键盘
    private var isDismissingKeyboard = false
    // ✅ 标记键盘是否正在显示
    private var isKeyboardShowing = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ✅ 从 LinkLoadingView 返回（取消或失败）时允许再次点击 Connect
        isNavigatingToNextPage = false
        continueButton.isEnabled = true
        continueButton.backgroundColor = .color(hexString: "#111111")
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = true
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = true
                tabBarController.homeAddButton?.isHidden = true
            }
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
        
        // ✅ 永久8位ID：仅从本地读出来刷新显示（生成/上传在 viewDidLoad 里统一处理）
        if let existingCode = CoupleStatusManager.shared.ownInvitationCode, existingCode.count == 8 {
            underunderinvitationLabel.text = existingCode
            invitationLabel.text = existingCode
            underinvitationLabel.text = existingCode
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // ✅ 无论是否在 tab 内，都必须移除 Firebase 监听器，否则 modal 呈现时 listener 会残留导致断开链接异常
        listenerRegistration?.remove()
        listenerRegistration = nil
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = false
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = false
                tabBarController.homeAddButton?.isHidden = false
            }
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
        // ✅ 移除通知监听，防止内存泄漏
        NotificationCenter.default.removeObserver(self)
        // ✅ 重置导航标志，防止状态不一致
        isNavigatingToNextPage = false
        // ✅ 页面消失时强制关闭键盘
        forceDismissKeyboard()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // 被动断开：在 setupUI 之后改文案（present 前已置 isPresentedFromPartnerUnlink）
        if isPresentedFromPartnerUnlink {
            conLabel.text = "Partner disconnected"
            shareLabel.text = "Your partner has unlinked. Shared data is no longer synced. You can link again with a new invitation code below."
            shareLabel.numberOfLines = 0
        }
        
        // ✅ 添加点击背景区域收起键盘的手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.cancelsTouchesInView = false // ✅ 不影响其他控件的点击事件
        view.addGestureRecognizer(tapGesture)
        
        let userUUID = CoupleStatusManager.shared.userUniqueUUID
        print("✅ App启动，当前用户唯一UUID：\(userUUID)")
        
        // ✅ 先尝试从已有数据加载邀请码（如果存在）
        if let existingCode = CoupleStatusManager.shared.ownInvitationCode, existingCode.count == 8 {
            self.underunderinvitationLabel.text = existingCode
            self.invitationLabel.text = existingCode
            self.underinvitationLabel.text = existingCode
            print("✅ CheekBootPageView: 从已有数据加载邀请码: \(existingCode)")
        }
        
        // ✅ 永久8位ID：确保本地/远端都准备好（不再5分钟过期、不再自动重生）
        CoupleStatusManager.shared.generateFirstLaunchId { [weak self] code in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let code = code, code.count == 8 {
                    self.underunderinvitationLabel.text = code
                    self.invitationLabel.text = code
                    self.underinvitationLabel.text = code
                }
                
                // ✅ 确保只启动一次监听器
                if self.listenerRegistration == nil {
                    self.startListeningForIncomingLink()
                }
            }
        }
        
        // ✅ 修复：监听键盘显示/隐藏通知，追踪键盘状态
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    // ✅ 键盘显示回调
    @objc private func keyboardWillShow() {
        isKeyboardShowing = true
        isDismissingKeyboard = false
    }
    
    // ✅ 键盘隐藏回调
    @objc private func keyboardWillHide() {
        isKeyboardShowing = false
        isDismissingKeyboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isDismissingKeyboard = false
        }
    }
    
    // MARK: - UI 布局
    private func setupUI() {
        view.backgroundColor = .white

        let bg = UIImageView(image: .bootbackiamge)
        bg.contentMode = .scaleAspectFill
        bg.clipsToBounds = true
        view.addSubview(bg)
        bg.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backButton = UIButton()
        backButton.setImage(UIImage(named: "arrow"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        maybeButton = UIButton()
        maybeButton.setTitle("Maybe Later", for: .normal)
        maybeButton.setTitleColor(.color(hexString: "#8A8E9D"), for: .normal)
        maybeButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        maybeButton.addTarget(self, action: #selector(maybeLaterTapped), for: .touchUpInside)
        view.addSubview(maybeButton)
        maybeButton.snp.makeConstraints { make in
            make.right.equalTo(-24)
            make.topMargin.equalTo(28)
        }
        
        puineImage = UIImageView(image: .linkphone)
        puineImage.contentMode = .scaleAspectFit
        view.addSubview(puineImage)
        let topSpacing = view.height() * 66 / 812
        puineImage.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(231.0 / 375.0)
            make.height.equalTo(puineImage.snp.width).multipliedBy(72.0 / 231.0)
            make.top.equalTo(maybeButton.snp.bottom).offset(topSpacing)
        }
        
        conLabel = UILabel()
        conLabel.text = "Connect with your partner"
        conLabel.textAlignment = .center
        conLabel.numberOfLines = 0
        conLabel.textColor = .color(hexString: "#322D3A")
        conLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)
        view.addSubview(conLabel)
        let titleSpacing = view.height() * 42 / 812
        conLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(puineImage.snp.bottom).offset(titleSpacing)
            make.left.right.equalToSuperview().inset(20)
        }
        
        shareLabel = UILabel()
        shareLabel.text = "Share your invitation code with your partner, or paste your partner's invitation code to connect."
        shareLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        shareLabel.numberOfLines = 0
        shareLabel.textColor = .color(hexString: "#8A8E9D")
        shareLabel.textAlignment = .center
        view.addSubview(shareLabel)
        let subTitleSpacing = view.height() * 10 / 812
        shareLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(conLabel.snp.bottom).offset(subTitleSpacing)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        invitationField = UIView()
        invitationField.backgroundColor = .color(hexString: "#FFFFFF")
        invitationField.layer.cornerRadius = 18
        view.addSubview(invitationField)
        invitationField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(shareLabel.snp.bottom).offset(20)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(83)
        }
        
        underunderinvitationLabel = BootStrokeShadowLabel()
        underunderinvitationLabel.text = "00000000"
        underunderinvitationLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderinvitationLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderinvitationLabel.shadowBlurRadius = 1.0
        underunderinvitationLabel.letterSpacing = 16.0
        underunderinvitationLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 28)!
        invitationField.addSubview(underunderinvitationLabel)
        underunderinvitationLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        underinvitationLabel = BootStrokeShadowLabel()
        underinvitationLabel.text = "00000000"
        underinvitationLabel.shadowColor = UIColor.black.withAlphaComponent(0.01)
        underinvitationLabel.shadowOffset = CGSize(width: 0, height: 2)
        underinvitationLabel.shadowBlurRadius = 4.0
        underinvitationLabel.letterSpacing = 16.0
        underinvitationLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 28)!
        invitationField.addSubview(underinvitationLabel)
        underinvitationLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        invitationLabel = BootGradientMaskLabel()
        invitationLabel.text = "00000000"
        invitationLabel.letterSpacing = 16.0
        invitationLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 28)!
        invitationLabel.gradientStartColor = .color(hexString: "#DF6DFF")
        invitationLabel.gradientEndColor = .color(hexString: "#7F87FF")
        invitationField.addSubview(invitationLabel)
        invitationLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        copyButton = UIButton()
        copyButton.setImage(UIImage(named: "copyButton"), for: .normal)
        copyButton.isUserInteractionEnabled = true
        copyButton.addTarget(self, action: #selector(copyInvitationCodeTapped), for: .touchUpInside)
        invitationField.addSubview(copyButton)
        copyButton.snp.makeConstraints { make in
            make.right.equalTo(-12)
            make.top.equalTo(12)
        }
        invitationField.bringSubviewToFront(copyButton)
        
        successdeView = UIView()
        successdeView.layer.borderWidth = 1
        successdeView.layer.borderColor = UIColor.color(hexString: "#E8E8E8").cgColor
        successdeView.backgroundColor = .color(hexString: "#FFFFFF")
        successdeView.layer.cornerRadius = 15
        successdeView.isHidden = true
        view.addSubview(successdeView)
        successdeView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(invitationField.snp.bottom).offset(14)
            make.height.equalToSuperview().multipliedBy(30.0 / 812.0)
        }
        
        let successdeImage = UIImageView(image: .checkCircle)
        successdeView.addSubview(successdeImage)
        successdeImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(4)
        }
        
        let successdeLabel = UILabel()
        successdeLabel.text = "Copy successful"
        successdeLabel.textColor = .color(hexString: "#8A8E9D")
        successdeLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        successdeView.addSubview(successdeLabel)
        successdeLabel.snp.makeConstraints { make in
            make.left.equalTo(successdeImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
            make.right.equalTo(-8)
        }
        
        let enterLabel = UILabel()
        enterLabel.text = "Enter Invite Code"
        enterLabel.textColor = .color(hexString: "#322D3A")
        enterLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)
        view.addSubview(enterLabel)
        let xxx102 = view.height() * 102.0 / 812.0
        enterLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(invitationField.snp.bottom).offset(xxx102)
        }
        
        partnerIdContainerView = UIView()
        partnerIdContainerView.backgroundColor = .color(hexString: "#FFFFFF")
        partnerIdContainerView.layer.cornerRadius = 18
        // ✅ 添加点击手势，点击容器时也弹出键盘输入视图
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(partnerIdTextFieldTapped))
        partnerIdContainerView.addGestureRecognizer(containerTapGesture)
        view.addSubview(partnerIdContainerView)
        partnerIdContainerView.snp.makeConstraints { make in
            let xxx12 = view.height() * 12.0 / 812.0
            make.top.equalTo(enterLabel.snp.bottom).offset(xxx12)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(83)
        }
        
        partnerIdBotLabel = BootStrokeShadowLabel()
        partnerIdBotLabel.text = "00000000"
        partnerIdBotLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        partnerIdBotLabel.shadowOffset = CGSize(width: 0, height: 1)
        partnerIdBotLabel.shadowBlurRadius = 1.0
        partnerIdBotLabel.letterSpacing = 16.0
        partnerIdBotLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 28)!
        partnerIdBotLabel.isUserInteractionEnabled = false
        partnerIdBotLabel.isHidden = true
        partnerIdContainerView.addSubview(partnerIdBotLabel)
        
        partnerIdBotLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        partnerIdMidLabel = BootStrokeShadowLabel()
        partnerIdMidLabel.text = "00000000"
        partnerIdMidLabel.shadowColor = UIColor.black.withAlphaComponent(0.01)
        partnerIdMidLabel.shadowOffset = CGSize(width: 0, height: 2)
        partnerIdMidLabel.shadowBlurRadius = 4.0
        partnerIdMidLabel.letterSpacing = 16.0
        partnerIdMidLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 28)!
        partnerIdMidLabel.isUserInteractionEnabled = false
        partnerIdMidLabel.isHidden = true
        partnerIdContainerView.addSubview(partnerIdMidLabel)
        partnerIdMidLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        partnerIdTopLabel = BootGradientMaskLabel()
        partnerIdTopLabel.letterSpacing = 16.0
        partnerIdTopLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 28)!
        partnerIdTopLabel.gradientStartColor = .color(hexString: "#7F9FFF")
        partnerIdTopLabel.gradientEndColor = .color(hexString: "#7F9FFF")
        partnerIdTopLabel.isUserInteractionEnabled = false
        partnerIdContainerView.addSubview(partnerIdTopLabel)
        partnerIdTopLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        partnerIdTextField = UITextField()
        partnerIdTextField.keyboardType = .numberPad
        partnerIdTextField.textAlignment = .center
        // ✅ 设置占位符文本和字体
        let placeholderText = "Enter code..."
        let placeholderFont = UIFont(name: "SFCompactRounded-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14)
        partnerIdTextField.attributedPlaceholder = NSAttributedString(
            string: placeholderText,
            attributes: [.font: placeholderFont]
        )
        partnerIdTextField.backgroundColor = .clear
        partnerIdTextField.tintColor = .clear
        partnerIdTextField.isOpaque = false
        partnerIdTextField.textColor = .clear
        partnerIdTextField.delegate = self
        // ✅ 添加点击手势，点击时弹出键盘输入视图
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(partnerIdTextFieldTapped))
        partnerIdTextField.addGestureRecognizer(tapGesture)
        partnerIdContainerView.addSubview(partnerIdTextField)
        partnerIdTextField.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // ✅ 唯一的第一响应者，键盘为其弹出；文字同步到 accessory 的 codeInputTextField 仅作显示，避免第一响应者切到 accessory 内导致第三方键盘崩溃/双键盘
        hiddenTextField = UITextField()
        hiddenTextField.isHidden = true
        hiddenTextField.keyboardType = .numberPad
        hiddenTextField.delegate = self
        hiddenTextField.addTarget(self, action: #selector(hiddenCodeTextFieldChanged), for: .editingChanged)
        view.addSubview(hiddenTextField)
        
        // ✅ 创建键盘上方的输入视图
        setupKeyboardInputView()
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Connect", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 18
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.addTarget(self, action: #selector(handleLinkToPartner), for: .touchUpInside)
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
    }
    
    // MARK: - 事件处理
    @objc private func backButtonTapped() {
        forceDismissKeyboard()
        // ✅ 如果是从断开链接弹窗 present 进来的，dismiss
        // ✅ 否则，如果是 push 进来的，pop
        if isPresentedFromUnlink || isPresentedFromPartnerUnlink || presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    @objc private func maybeLaterTapped() {
        forceDismissKeyboard()
        dismiss(animated: true)
        isNavigatingToNextPage = true
     
        
        // ✅ 延迟重置标志
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isNavigatingToNextPage = false
        }
    }
    
    @objc private func copyInvitationCodeTapped() {
        let code = underunderinvitationLabel.text
        guard code.count == 8, code != "00000000" else {
            AlertManager.showSingleButtonAlert(message: "Invitation code not generated, cannot be copied", target: self)
            return
        }
        
        let pasteboard = UIPasteboard.general
        pasteboard.string = code
        self.showSuccessViewAndAutoDismiss()
        
        copyButton.isUserInteractionEnabled = false
        copyButton.alpha = 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.isUserInteractionEnabled = true
            self?.copyButton.alpha = 1.0
        }
        
        print("✅ 邀请码 \(code) 已成功复制到粘贴板")
    }
    
    @objc private func handleLinkToPartner() {
        forceDismissKeyboard()
        let partnerRaw = (partnerIdTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let partnerCode = String(partnerRaw.filter { $0.isNumber }.prefix(8))
        guard partnerCode.count == 8 else {
            AlertManager.showSingleButtonAlert(message: "Please enter a valid 8-digit ID.", target: self)
            return
        }
        
        guard let ownCode = CoupleStatusManager.shared.ownInvitationCode, ownCode.count == 8 else {
            AlertManager.showSingleButtonAlert(message: "Your ID is not ready yet. Please try again.", target: self)
            return
        }
        
        if partnerCode == ownCode {
            AlertManager.showSingleButtonAlert(message: "⚠️ You cannot link your own ID.", target: self)
            return
        }
        
        guard !isNavigatingToNextPage else { return }
        BootOnboardingFeedback.playContinueButton()
        isNavigatingToNextPage = true
        let loading = CheekLinkLoadingView(partnerCode: partnerCode)
        loading.modalPresentationStyle = .fullScreen
        loading.onModalLinkSuccess = { [weak self] in
            let success = CheekLinkSuccessView()
            success.isFromCheekBootModal = true
            self?.navigationController?.pushViewController(success, animated: true)
        }
        present(loading, animated: true)
    }
    
    private func showSuccessViewAndAutoDismiss() {
        successdeView.isHidden = false
        successdeView.alpha = 0.0
        UIView.animate(withDuration: 0.2) {
            self.successdeView.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5) {
                self.successdeView.alpha = 0.0
            } completion: { _ in
                self.successdeView.isHidden = true
            }
        }
    }
    
    // MARK: - 导航
    // ✅ 防止重复跳转：标记是否正在跳转
    private var isNavigatingToNextPage = false
    
    private func updateContinueButtonState() {
        let text = partnerIdTextField.text ?? ""
        let isValid = text.count == 8 && text.allSatisfy({ $0.isNumber })
        let isEnabled = isValid && !CoupleStatusManager.shared.isUserLinked
        
        continueButton.isEnabled = isEnabled
        continueButton.backgroundColor = isEnabled ? .color(hexString: "#111111") : .systemGray
    }
    
    private func startListeningForIncomingLink() {
        // ✅ 防止重复注册监听器
        guard listenerRegistration == nil else {
            print("🔗 [Firebase链接] CheekBootPageView: 监听器已存在，跳过重复注册")
            return
        }
        
        guard let ownCode = CoupleStatusManager.shared.ownInvitationCode else {
            print("🔗 [Firebase链接] ❌ CheekBootPageView: 未找到自己的邀请码，无法启动监听")
            return
        }
        
        print("🔗 [Firebase链接] ========== 被动链接监听启动 (CheekBootPageView) ==========")
        print("🔗 [Firebase链接] 步骤0: 监听 Firebase linked_couples/\(ownCode)...")
        
        let db = Firestore.firestore()
        listenerRegistration = db.collection("linked_couples").document(ownCode).addSnapshotListener { [weak self] (documentSnapshot, error) in
            guard let self = self, let document = documentSnapshot else { return }
            // ✅ 只处理服务端数据，避免断开后进链接页时缓存仍带旧文档导致误判「被链接」
            if document.metadata.isFromCache { return }
            if document.exists, let partnerId = document.data()?["partnerId"] as? String {
                // ✅ 防止重复处理：检查是否已链接且没有正在跳转
                if !CoupleStatusManager.shared.isUserLinked && !self.isNavigatingToNextPage {
                    print("🔗 [Firebase链接] 步骤1: 监听到 linked_couples 有 partnerId=\(partnerId)，被对方链接！")
                    
                    // ✅ 链接成功时先关闭键盘
                    self.forceDismissKeyboard()
                    
                    // ✅ 标记正在跳转，防止重复处理
                    self.isNavigatingToNextPage = true
                    
                    print("🔗 [Firebase链接] 步骤2: 本地 setLinked + UserDefaults")
                    let isInitiator = false
                    CoupleStatusManager.shared.setLinked(partnerId: partnerId, isInitiator: isInitiator)
                    UserDefaults.standard.set(true, forKey: self.kIsCoupleLinked)
                    UserDefaults.standard.synchronize()
                    
                    print("🔗 [Firebase链接] 步骤3: 正在 syncCoupleUserInfoAfterLink...")
                    UserManger.manager.syncCoupleUserInfoAfterLink(partner8DigitId: partnerId) { success in
                        if success {
                            print("🔗 [Firebase链接] 步骤3完成: 用户信息同步成功")
                        } else {
                            print("🔗 [Firebase链接] ⚠️ 步骤3: 用户信息同步失败")
                        }
                        
                        // ✅ 发送链接成功通知，让各Manager重启监听器
                        print("🔗 [Firebase链接] 步骤4: 发送 CoupleDidLinkNotification，跳转 CheekLinkSuccessView")
                        NotificationCenter.default.post(name: NSNotification.Name("CoupleDidLinkNotification"), object: nil)
                        
                        // ✅ 链接成功后进入 CheekLinkSuccessView
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            guard self.isViewLoaded && self.view.window != nil else {
                                self.isNavigatingToNextPage = false
                                return
                            }
                            UnlinkConfirmPopup.forceRemoveFromAllWindows()
                            let success = CheekLinkSuccessView()
                            success.isFromCheekBootModal = true
                            self.navigationController?.pushViewController(success, animated: true)
                            self.isNavigatingToNextPage = false
                            print("🔗 [Firebase链接] ========== 被动链接流程结束 (CheekBootPageView) ==========")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - ✅ 键盘输入视图设置
    private func setupKeyboardInputView() {
        keyboardInputView = UIView()
        keyboardInputView.backgroundColor = .white
        
        let screenWidth = UIScreen.main.bounds.width
        keyboardInputView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 60)
        keyboardInputView.autoresizingMask = [.flexibleWidth]
        
        // ✅ 右侧 Done 按钮（收起键盘）
        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle("Done", for: .normal)
        doneBtn.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 16)!
        doneBtn.setTitleColor(.color(hexString: "#111111"), for: .normal)
        doneBtn.addTarget(self, action: #selector(forceDismissKeyboard), for: .touchUpInside)
        keyboardInputView.addSubview(doneBtn)
        doneBtn.snp.makeConstraints { make in
            make.right.equalTo(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(56)
            make.height.equalTo(44)
        }
        
        // ✅ 输入框容器
        let inputContainerView = UIView()
        inputContainerView.backgroundColor = .color(hexString: "#F5F5F5")
        inputContainerView.layer.cornerRadius = 18
        keyboardInputView.addSubview(inputContainerView)
        
        inputContainerView.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.right.equalTo(doneBtn.snp.left).offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
        }
        
        // ✅ 输入框（在 accessory 中仅作显示，真正输入在 hiddenTextField）
        codeInputTextField = UITextField()
        codeInputTextField.keyboardType = .numberPad
        codeInputTextField.backgroundColor = .clear
        codeInputTextField.font = UIFont(name: "SFCompactRounded-Bold", size: 20)!
        codeInputTextField.textColor = .color(hexString: "#322D3A")
        codeInputTextField.textAlignment = .left
        codeInputTextField.isUserInteractionEnabled = false
        inputContainerView.addSubview(codeInputTextField)
        
        codeInputTextField.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.right.equalTo(-15)
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
        }
        
        // ✅ 键盘上方的输入栏作为 hiddenTextField 的 accessory，hiddenTextField 在 window 内才能弹出键盘
        hiddenTextField.inputAccessoryView = keyboardInputView
    }
    
    // ✅ 邀请码输入框点击 - 仅让 hiddenTextField 成为第一响应者，不切到 accessory 内，避免第三方键盘崩溃/双键盘
    @objc private func partnerIdTextFieldTapped() {
        guard !isDismissingKeyboard else { return }
        let currentCode = partnerIdTextField.text ?? ""
        hiddenTextField.text = currentCode
        codeInputTextField.text = currentCode
        hiddenCodeTextFieldChanged()
        if hiddenTextField.isFirstResponder {
            isKeyboardShowing = true
            return
        }
        forceDismissKeyboard()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hiddenTextField.becomeFirstResponder()
            self.isKeyboardShowing = true
        }
    }

    @objc private func hiddenCodeTextFieldChanged() {
        let raw = hiddenTextField.text ?? ""
        let digitsOnly = raw.filter { $0.isNumber }
        let filtered = String(digitsOnly.prefix(8))
        if filtered != raw {
            hiddenTextField.text = filtered
        }
        codeInputTextField.text = filtered
        partnerIdTextField.text = filtered
        if !filtered.isEmpty {
            partnerIdBotLabel.isHidden = false
            partnerIdMidLabel.isHidden = false
        } else {
            partnerIdBotLabel.isHidden = true
            partnerIdMidLabel.isHidden = true
        }
        partnerIdBotLabel.text = filtered
        partnerIdMidLabel.text = filtered
        partnerIdTopLabel.text = filtered
        updateContinueButtonState()
    }

    @objc private func forceDismissKeyboard() {
        isDismissingKeyboard = true
        hiddenTextField?.resignFirstResponder()
        partnerIdTextField?.resignFirstResponder()
        view.endEditing(true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isDismissingKeyboard = false
        }
    }
    
    // ✅ 点击背景区域收起键盘
    @objc private func dismissKeyboard(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: view)
        let isTapOnPartnerContainer = partnerIdContainerView.frame.contains(touchPoint)
        let isTapOnInvitationField = invitationField.frame.contains(touchPoint)
        
        if !isTapOnPartnerContainer && !isTapOnInvitationField {
            forceDismissKeyboard()
        }
    }
    
}

// MARK: - UITextFieldDelegate 8位纯数字限制
extension CheekBootPageView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // ✅ hiddenTextField 为唯一第一响应者，限制 8 位数字
        if textField == hiddenTextField {
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
            let digitsOnly = newText.filter { $0.isNumber }
            return digitsOnly.count <= 8
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == hiddenTextField || textField == codeInputTextField {
            isKeyboardShowing = true
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        isKeyboardShowing = false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        forceDismissKeyboard()
        return true
    }
}
