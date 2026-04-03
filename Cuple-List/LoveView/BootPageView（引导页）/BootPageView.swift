//
//  BootPageView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class BootPageView: UIViewController {
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
    private var errorView: UIView! // 错误提示视图
    private var errorLabel: UILabel! // 错误提示标签
    private var listenerRegistration: ListenerRegistration?
    private let kIsCoupleLinked = "isCoupleLinked"
    
    // ✅ 键盘输入相关 - 修复：增加键盘状态追踪
    private var hiddenTextField: UITextField! // 隐藏的TextField，用于弹出键盘
    private var keyboardInputView: UIView! // 键盘上方的输入视图
    private var codeInputTextField: UITextField! // 输入框（在键盘上方）
    private var isDismissingKeyboard = false
    // ✅ 新增：标记键盘是否正在显示
    private var isKeyboardShowing = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从订阅页返回时，订阅页 viewWillDisappear 可能再次露出 TabBar；此处强制保持隐藏直到完成引导
        if !UserDefaults.standard.bool(forKey: "hasLaunchedOnce"),
           let tab = tabBarController as? MomoTabBarController {
            tab.setTabBarHidden(true)
            tab.tabBar.isUserInteractionEnabled = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.bootPage)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // ✅ 移除监听器，防止内存泄漏
        listenerRegistration?.remove()
        listenerRegistration = nil
        // ✅ 移除通知监听，防止内存泄漏
        NotificationCenter.default.removeObserver(self)
        // ✅ 重置导航标志，防止状态不一致
        isNavigatingToNextPage = false
        
        // ✅ 修复：页面消失时强制关闭键盘
        forceDismissKeyboard()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // ✅ 设置按钮初始状态（灰色且禁用）
        updateContinueButtonState()
        
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
            print("✅ BootPageView: 从已有数据加载邀请码: \(existingCode)")
        }
        
        CoupleStatusManager.shared.generateFirstLaunchId { [weak self] code in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // ✅ 如果生成成功，更新显示；如果失败但已有邀请码，保持显示
                if let code = code, code.count == 8 {
                    self.underunderinvitationLabel.text = code
                    self.invitationLabel.text = code
                    print("✅ BootPageView: 生成/更新邀请码: \(code)")
                } else if let existingCode = CoupleStatusManager.shared.ownInvitationCode, existingCode.count == 8 {
                    // ✅ 如果生成失败，但已有邀请码，使用已有的
                    self.underunderinvitationLabel.text = existingCode
                    self.invitationLabel.text = existingCode
                    print("✅ BootPageView: 生成失败，使用已有邀请码: \(existingCode)")
                } else {
                    print("⚠️ BootPageView: 无法获取邀请码，显示默认值")
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
    
    // ✅ 新增：键盘显示回调
    @objc private func keyboardWillShow() {
        isKeyboardShowing = true
        isDismissingKeyboard = false
    }
    
    // ✅ 新增：键盘隐藏回调
    @objc private func keyboardWillHide() {
        isKeyboardShowing = false
        isDismissingKeyboard = true
        // 延迟重置标记，防止快速点击再次触发
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
            make.width.equalToSuperview().multipliedBy(238.0 / 375.0)
            make.height.equalTo(puineImage.snp.width).multipliedBy(80.0 / 231.0)
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
        shareLabel.text = "Share your invite code with your partner, or enter theirs to link your accounts."
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
        let placeholderText = "Paste or enter code"
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
        
        successdeView = UIView()
        successdeView.layer.borderWidth = 1
        successdeView.layer.borderColor = UIColor.color(hexString: "#E8E8E8").cgColor
        successdeView.backgroundColor = .color(hexString: "#FFFFFF")
        successdeView.layer.cornerRadius = 15
        successdeView.isHidden = true
        view.addSubview(successdeView)
        successdeView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(partnerIdTextField.snp.bottom).offset(12)
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
        
        // ✅ 唯一的第一响应者，键盘为其弹出；文字同步到 accessory 的 codeInputTextField 仅作显示，避免第一响应者切到 accessory 内导致第三方键盘崩溃/双键盘
        hiddenTextField = UITextField()
        hiddenTextField.isHidden = true
        hiddenTextField.keyboardType = .numberPad
        hiddenTextField.delegate = self
        hiddenTextField.addTarget(self, action: #selector(hiddenCodeTextFieldChanged), for: .editingChanged)
        view.addSubview(hiddenTextField)
        
        // ✅ 创建键盘上方的输入视图
        setupKeyboardInputView()
        
        // ✅ 创建错误提示视图（红色，显示在邀请输入框下方）
        errorView = UIView()
        errorView.layer.borderWidth = 1
        errorView.layer.borderColor = UIColor.color(hexString: "#FFFFFF").cgColor
        errorView.backgroundColor = .color(hexString: "#FFF5F5")
        errorView.layer.cornerRadius = 15
        errorView.isHidden = true
        view.addSubview(errorView)
        errorView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(partnerIdContainerView.snp.bottom).offset(11)
            make.height.equalToSuperview().multipliedBy(30.0 / 812.0)
        }
        
        let errorImage = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        errorImage.tintColor = .color(hexString: "#FF5E5E")
        errorView.addSubview(errorImage)
        errorImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(4)
            make.width.height.equalTo(22)
        }
        
        errorLabel = UILabel()
        errorLabel.text = "Invitation code error"
        errorLabel.textColor = .color(hexString: "#FF5E5E")
        errorLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        errorView.addSubview(errorLabel)
        errorLabel.snp.makeConstraints { make in
            make.left.equalTo(errorImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
            make.right.equalTo(-8)
        }
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Connect", for: .normal)
        // ✅ 初始状态：灰色且禁用
        continueButton.backgroundColor = .systemGray
        continueButton.isEnabled = false
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
        // ✅ 修复：返回时先关闭键盘
        forceDismissKeyboard()
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func maybeLaterTapped() {
        // ✅ 防止重复跳转
        guard !isNavigatingToNextPage else {
            print("⚠️ BootPageView: 正在跳转中，跳过重复调用 maybeLaterTapped")
            return
        }
        
        // ✅ 修复：跳转前先关闭键盘
        forceDismissKeyboard()
        
        // ✅ Maybe Later：始终弹出订阅页，订阅成功才进入
        isNavigatingToNextPage = true
        let enterApp = { [weak self] in
            guard let self = self else { return }
            UserDefaults.standard.set(true, forKey: "hasLaunchedOnce")
            UserDefaults.standard.synchronize()
            BootOnboardingFlow.finishAndShowHome(from: self)
        }
        let vip = VipUIViewController()
        vip.handler = enterApp
        navigationController?.pushViewController(vip, animated: true)
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
        
    }
    
    @objc private func handleLinkToPartner() {
        // ✅ 防止重复跳转
        guard !isNavigatingToNextPage else {
            print("⚠️ BootPageView: 正在跳转中，跳过重复调用 handleLinkToPartner")
            return
        }
        
        forceDismissKeyboard()
        
        guard let partnerCode = partnerIdTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              partnerCode.count == 8, partnerCode.allSatisfy({ $0.isNumber }) else {
            return
        }
        
        guard let ownCode = CoupleStatusManager.shared.ownInvitationCode, ownCode.count == 8 else {
            showErrorViewAndAutoDismiss(message: "Your ID is not ready yet. Please try again.")
            return
        }
        
        if partnerCode == ownCode {
            showErrorViewAndAutoDismiss(message: "You cannot link your own ID.")
            return
        }
        
        BootOnboardingFeedback.playContinueButton()
        isNavigatingToNextPage = true
        let loading = LinkLoadingView(partnerCode: partnerCode)
        navigationController?.pushViewController(loading, animated: true)
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
    
    // ✅ 显示错误提示并自动隐藏
    private func showErrorViewAndAutoDismiss(message: String) {
        // 更新错误消息
        errorLabel.text = message
        
        errorView.isHidden = false
        errorView.alpha = 0.0
        UIView.animate(withDuration: 0.2) {
            self.errorView.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0) {
                self.errorView.alpha = 0.0
            } completion: { _ in
                self.errorView.isHidden = true
            }
        }
    }
    
    private func updateContinueButtonState() {
        let text = partnerIdTextField.text ?? ""
        let isValid = text.count == 8 && text.allSatisfy({ $0.isNumber })
        let isEnabled = isValid && !CoupleStatusManager.shared.isUserLinked
        
        continueButton.isEnabled = isEnabled
        continueButton.backgroundColor = isEnabled ? .color(hexString: "#111111") : .systemGray
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
        
        // ✅ 键盘上方的输入栏作为 hiddenTextField 的 accessory，这样先让 hiddenTextField（在 window 内）成为第一响应者才能弹出键盘
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
    
    // ✅ 修复：强制关闭键盘的统一方法
    @objc private func forceDismissKeyboard() {
        isDismissingKeyboard = true
        
        hiddenTextField?.resignFirstResponder()
        partnerIdTextField?.resignFirstResponder()
        view.endEditing(true)
        
        // 延迟重置标记
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isDismissingKeyboard = false
        }
    }
    
    // ✅ 点击背景区域收起键盘
    @objc private func dismissKeyboard(_ gesture: UITapGestureRecognizer) {
        // ✅ 修复：判断点击位置，避免点击输入框区域也关闭键盘
        let touchPoint = gesture.location(in: view)
        
        // 检查是否点击了输入容器区域
        let isTapOnPartnerContainer = partnerIdContainerView.frame.contains(touchPoint)
        let isTapOnInvitationField = invitationField.frame.contains(touchPoint)
        
        if !isTapOnPartnerContainer && !isTapOnInvitationField {
            forceDismissKeyboard()
        }
    }
    
    // ✅ 防止重复跳转：标记是否正在跳转
    private var isNavigatingToNextPage = false
    
    private func startListeningForIncomingLink() {
        // ✅ 防止重复注册监听器
        guard listenerRegistration == nil else {
            print("🔗 [Firebase链接] BootPageView: 监听器已存在，跳过重复注册")
            return
        }
        
        guard let ownCode = CoupleStatusManager.shared.ownInvitationCode else {
            print("🔗 [Firebase链接] ❌ BootPageView: 未找到自己的邀请码，无法启动监听")
            return
        }
        
        print("🔗 [Firebase链接] ========== 被动链接监听启动 (BootPageView) ==========")
        print("🔗 [Firebase链接] 步骤0: 监听 Firebase linked_couples/\(ownCode)...")
        
        let db = Firestore.firestore()
        listenerRegistration = db.collection("linked_couples").document(ownCode).addSnapshotListener { [weak self] (documentSnapshot, error) in
            guard let self = self, let document = documentSnapshot else { return }
            
            if document.exists, let partnerId = document.data()?["partnerId"] as? String {
                // ✅ 防止重复处理：检查是否已链接且没有正在跳转
                if !CoupleStatusManager.shared.isUserLinked && !self.isNavigatingToNextPage {
                    print("🔗 [Firebase链接] 步骤1: 监听到 linked_couples 有 partnerId=\(partnerId)，被对方链接！")
                    
                    // ✅ 修复：链接成功时先关闭键盘
                    self.forceDismissKeyboard()
                    
                    // ✅ 标记正在跳转，防止重复处理
                    self.isNavigatingToNextPage = true
                    
                    print("🔗 [Firebase链接] 步骤2: 本地 setLinked + UserDefaults")
                    let isInitiator = false
                    CoupleStatusManager.shared.setLinked(partnerId: partnerId, isInitiator: isInitiator)
                    UserDefaults.standard.set(true, forKey: self.kIsCoupleLinked)
                    UserDefaults.standard.synchronize()
                    
                    // ✅ 先读取对方UUID（从 pending_invitations 中读取，此时文档还存在）
                    print("🔗 [Firebase链接] 步骤3: 读取 Firebase pending_invitations/\(ownCode) 获取对方 UUID...")
                    db.collection("pending_invitations").document(ownCode).getDocument { [weak self] (snapshot, error) in
                        guard let self = self else { return }
                        
                        if let snapshot = snapshot, snapshot.exists {
                            let partnerUUID = snapshot.data()?["userUUID"] as? String ?? ""
                            if !partnerUUID.isEmpty {
                                print("🔗 [Firebase链接] 步骤3完成: 读取到对方 UUID=\(partnerUUID.prefix(8))...")
                            } else {
                                print("🔗 [Firebase链接] ⚠️ 步骤3: pending_invitations 中无 userUUID")
                            }
                        } else {
                            print("🔗 [Firebase链接] ⚠️ 步骤3: pending_invitations 文档不存在或读取失败")
                        }
                        
                        // ✅ 同步用户信息
                        print("🔗 [Firebase链接] 步骤4: 正在 syncCoupleUserInfoAfterLink...")
                        UserManger.manager.syncCoupleUserInfoAfterLink(partner8DigitId: partnerId) { success in
                            if success {
                                print("🔗 [Firebase链接] 步骤4完成: 用户信息同步成功")
                            } else {
                                print("🔗 [Firebase链接] ⚠️ 步骤4: 用户信息同步失败")
                            }
                            
                            // ✅ 发送链接成功通知，让各Manager重启监听器
                            print("🔗 [Firebase链接] 步骤5: 发送 CoupleDidLinkNotification，跳转 LinkSuccessView")
                            NotificationCenter.default.post(name: NSNotification.Name("CoupleDidLinkNotification"), object: nil)
                            
                            // ✅ 链接成功后跳转到链接成功页面（LinkSuccessView）
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                // ✅ 检查页面是否还在
                                guard self.isViewLoaded && self.view.window != nil else {
                                    self.isNavigatingToNextPage = false
                                    return
                                }
                                
                                // ✅ 检查是否已经在 LinkSuccessView
                                if let topVC = self.navigationController?.topViewController, topVC is LinkSuccessView {
                                    print("⚠️ BootPageView: 已经在 LinkSuccessView，跳过重复跳转")
                                    self.isNavigatingToNextPage = false
                                    return
                                }
                                
                                let success = LinkSuccessView()
                                success.isCompletingOnboardingAfterLink = true
                                self.navigationController?.pushViewController(success, animated: true)
                                print("🔗 [Firebase链接] ========== 被动链接流程结束 (BootPageView) ==========")
                                // ✅ 延迟重置标志
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    self.isNavigatingToNextPage = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate 8位纯数字限制
extension BootPageView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // ✅ 只对键盘上方的输入框进行限制
        if textField == codeInputTextField {
            let numberSet = CharacterSet.decimalDigits
            if !string.isEmpty && string.rangeOfCharacter(from: numberSet.inverted) != nil {
                return false
            }
            
            let currentText = textField.text ?? ""
            let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
            return newText.count <= 8
        }
        
        // ✅ hiddenTextField 为唯一第一响应者，允许输入（会同步到 codeInputTextField 显示）
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
    
    // ✅ 新增：输入框结束编辑时的处理
    func textFieldDidEndEditing(_ textField: UITextField) {
        isKeyboardShowing = false
    }
    
    // ✅ 新增：点击键盘return键时关闭键盘
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        forceDismissKeyboard()
        return true
    }
}

