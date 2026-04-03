//
//  UserAvatarViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit
import PhotosUI
import CoreData
import MagicalRecord

class UserAvatarViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate {
    
    // MARK: - 生命周期
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLinkUnlinkButtonVisibility()
        // 隐藏底部TabBar
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = true
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = true
                tabBarController.homeAddButton?.isHidden = true
            }
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
        // 延迟加载，避免阻塞页面切换动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isViewLoaded, self.view.window != nil else { return }
            self.loadUserAvatarAndName()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 恢复底部TabBar
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = false
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = false
                tabBarController.homeAddButton?.isHidden = false
            }
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
//        loadUUIDData()
        loadUserAvatarAndName()
        addNotification()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: CoupleStatusManager.coupleDidUnlinkNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CoupleDidLinkNotification"), object: nil)
    }
//    
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        // 头像底部 view 设为圆形
//        if avatarImageView != nil, avatarImageView.bounds.width > 0 {
//            avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
//            avatarImageView.clipsToBounds = true
//        }
//    }
    
    // MARK: - 页面控件
    var backButton: UIButton!
    var avatarImageView: UIImageView!
    var avatarSelectButton: UIButton! // 重命名：原acaterButton，语义更清晰
    var toptext: UILabel!  // 核心用户名显示Label
    var toptextunderLabel: StrokeShadowLabel!
    var toptextunderunderLabel: StrokeShadowLabel!
    var reNameButton: UIButton!
    var dataButton: BorderGradientButton!
    var genderButton: BorderGradientButton!
    var unlinkButton: BorderGradientButton!
    /// 未连接时显示的「Add Partner」按钮容器（底部渐变按钮）
    var addPartnerContainerView: UIView!
    /// Add Partner 按钮上的渐变层（左上 #EC82FF → 右下 #6EB4FF）
    private var addPartnerGradientLayer: CAGradientLayer?
    /// 未连接时显示的「Add Partner」按钮，点击 present CheekBootPageView
    var linkContinueButton: UIButton!
    let genderPopup = GenderPopup()
    let birthdayPopup = BirthdayDatePopup() // 实例属性，防止被释放
    var myUUIDLabel: UILabel!
    var partnerUUIDLabel: UILabel!
    var birthdayDateLabel: UILabel! // 显示生日日期的 Label
    
    /// 点击空白收起键盘时置为 true，避免同一次点击触发名字/铅笔再弹键盘
    private var isDismissingKeyboard = false
    
    /// 切换性别成功提示视图（与 Copy successful 同风格）
    private var switchSuccessView: UIView!
    /// switchSuccessView 的底部约束，根据是否有底部按钮动态调整
    private var switchSuccessBottomConstraint: Constraint?
    
    // ✅ 键盘输入相关
    var hiddenTextField: UITextField! // 隐藏的TextField，用于弹出键盘
    var keyboardInputView: UIView! // 键盘上方的输入视图
    var nameInputTextField: UITextField! // 输入框
    
    // MARK: - UI布局
    func setUI() {
        view.backgroundColor = .white
        
        // 渐变背景
        let backView = ViewGradientView()
        view.addSubview(backView)
        backView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 返回按钮
        backButton = UIButton()
        backButton.setImage(UIImage(named: "breakback"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.topMargin.equalTo(24)
        }
        
        // 头像显示：先设统一占位图，避免进入页面时先闪“空/其他”再恢复
        avatarImageView = UIImageView()
        avatarImageView.contentMode = .scaleAspectFit
        avatarImageView.image = UIImage(named: "userText")  // 占位，loadUserAvatarAndName 会替换为真实或性别默认
        avatarImageView.applyAvatarCutoutShadow()
        avatarImageView.isUserInteractionEnabled = true // ✅ 点击头像区域也可触发「选择头像」
        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarButtonTapped))
        avatarImageView.addGestureRecognizer(avatarTapGesture)
        view.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(33)
            make.width.equalToSuperview().multipliedBy(103.0 / 375.0)
            make.height.equalTo(avatarImageView.snp.width)
        }
        
        toptextunderLabel = StrokeShadowLabel()
        toptextunderLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        toptextunderLabel.shadowOffset = CGSize(width: 0, height: 1)
        toptextunderLabel.shadowBlurRadius = 1.0
        toptextunderLabel.text = "YourName"
        toptextunderLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 23)!
        view.addSubview(toptextunderLabel)
        toptextunderLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(15)
            make.centerX.equalToSuperview()
        }
////        
        toptextunderunderLabel = StrokeShadowLabel()
        toptextunderunderLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        toptextunderunderLabel.shadowOffset = CGSize(width: 0, height: 1)
        toptextunderunderLabel.shadowBlurRadius = 5.0
        toptextunderunderLabel.text = "YourName"
        toptextunderunderLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 23)!
        
        view.addSubview(toptextunderunderLabel)
        
        toptextunderunderLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(15)
            make.centerX.equalToSuperview()
        }
        
//         用户名显示
        toptext = UILabel()
        toptext.text = "YourName" // ✅ 默认显示 YourName
        toptext.font = UIFont(name: "SFCompactRounded-Bold", size: 23)
        toptext.textColor = .color(hexString: "#8A8E9D") // ✅ 默认颜色为灰色
        toptext.isUserInteractionEnabled = true // ✅ 允许点击
        // ✅ 添加点击手势，点击用户名也可以编辑
        let nameTapGesture = UITapGestureRecognizer(target: self, action: #selector(renameButtonTapped))
        toptext.addGestureRecognizer(nameTapGesture)
        view.addSubview(toptext)
        toptext.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(15)
            make.centerX.equalToSuperview()
        }
        
        
        
        // 重命名按钮
        reNameButton = UIButton()
        reNameButton.setImage(UIImage(named: "settingpencil"), for: .normal)
        reNameButton.adjustsImageWhenHighlighted = false
        reNameButton.addTarget(self, action: #selector(renameButtonTapped), for: .touchUpInside)
        view.addSubview(reNameButton)
        reNameButton.snp.makeConstraints { make in
            make.left.equalTo(toptext.snp.right).offset(5)
            make.centerY.equalTo(toptext)
        }
        
        // 头像选择按钮（原acaterButton）- 修正布局，贴合头像右上角
        avatarSelectButton = UIButton()
        avatarSelectButton.setImage(UIImage(named: "addpic"), for: .normal)
        avatarSelectButton.adjustsImageWhenHighlighted = false
        avatarSelectButton.addTarget(self, action: #selector(avatarButtonTapped), for: .touchUpInside)
        view.addSubview(avatarSelectButton)
        avatarSelectButton.snp.makeConstraints { make in
            make.right.equalTo(avatarImageView.snp.right).offset(5)
            make.bottom.equalTo(avatarImageView.snp.bottom).offset(5)
            make.size.equalTo(CGSize(width: 30, height: 30)) // 固定尺寸，防止偏移
        }
        
        // 纪念日按钮
        dataButton = BorderGradientButton()
        dataButton.isHidden = true
        dataButton.layer.cornerRadius = 18
        dataButton.addTarget(self, action: #selector(birthdayButtonTapped), for: .touchUpInside)
        view.addSubview(dataButton)
        dataButton.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.top.equalTo(toptext.snp.bottom).offset(30)
        }
        // 纪念日按钮 - 右侧下拉箭头
        let datarightImage = UIImageView(image: UIImage(named: "adddown"))
        dataButton.addSubview(datarightImage)
        datarightImage.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.centerY.equalToSuperview()
        }
        // 纪念日按钮 - 左侧图标
        let datingImageView = UIImageView(image: UIImage(named: "dateimage"))
        dataButton.addSubview(datingImageView)
        datingImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(11)
        }
        // 纪念日按钮 - 左侧文字
        let datingLabel = UILabel()
        datingLabel.text = "Dating Anniversary"
        datingLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        datingLabel.textColor = .color(hexString: "#322D3A")
        dataButton.addSubview(datingLabel)
        datingLabel.snp.makeConstraints { make in
            make.left.equalTo(datingImageView.snp.right).offset(5)
            make.centerY.equalToSuperview()
        }
        // 纪念日按钮 - 右侧日期显示
        birthdayDateLabel = UILabel()
        birthdayDateLabel.text = "未设置"
        birthdayDateLabel.textColor = .color(hexString: "#999DAB")
        birthdayDateLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        birthdayDateLabel.tag = 1002
        dataButton.addSubview(birthdayDateLabel)
        birthdayDateLabel.snp.makeConstraints { make in
            make.right.equalTo(datarightImage.snp.left).offset(-10)
            make.centerY.equalToSuperview()
        }
        
        // 性别按钮
        genderButton = BorderGradientButton()
        genderButton.layer.cornerRadius = 18
        genderButton.addTarget(self, action: #selector(genderButtonTapped), for: .touchUpInside)
        view.addSubview(genderButton)
        genderButton.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.top.equalTo(toptext.snp.bottom).offset(30)
//            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
//            make.height.equalTo(52)
//            make.centerX.equalToSuperview()
//            make.top.equalTo(dataButton.snp.bottom).offset(15)
        }
        // 性别按钮 - 右侧下拉箭头
        let genderrightImage = UIImageView(image: UIImage(named: "adddown"))
        genderButton.addSubview(genderrightImage)
        genderrightImage.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.centerY.equalToSuperview()
        }
        // 性别按钮 - 左侧图标
        let genderImageView = UIImageView(image: UIImage(named: "pinkuser"))
        genderButton.addSubview(genderImageView)
        genderImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(11)
        }
        // 性别按钮 - 左侧文字（修正命名：原fenderLabel）
        let genderLabel = UILabel()
        genderLabel.text = "Gender"
        genderLabel.textColor = .color(hexString: "#322D3A")
        genderLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        genderButton.addSubview(genderLabel)
        genderLabel.snp.makeConstraints { make in
            make.left.equalTo(genderImageView.snp.right).offset(5)
            make.centerY.equalToSuperview()
        }
        // 性别按钮 - 右侧性别显示
        let genderValueLabel = UILabel()
        genderValueLabel.text = "未设置"
        genderValueLabel.textColor = .color(hexString: "#999DAB")
        genderValueLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        genderValueLabel.tag = 1001
        genderButton.addSubview(genderValueLabel)
        genderValueLabel.snp.makeConstraints { make in
            make.right.equalTo(genderrightImage.snp.left).offset(-10)
            make.centerY.equalToSuperview()
        }
        
        // 解绑按钮
        unlinkButton = BorderGradientButton()
        unlinkButton.layer.cornerRadius = 18
        unlinkButton.addTarget(self, action: #selector(unlinkButtonTapped), for: .touchUpInside)
        view.addSubview(unlinkButton)
        unlinkButton.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.top.equalTo(genderButton.snp.bottom).offset(15)
        }
        // 解绑按钮 - 右侧下拉箭头
        let unlinkrightImage = UIImageView(image: UIImage(named: "adddown"))
        unlinkButton.addSubview(unlinkrightImage)
        unlinkrightImage.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.centerY.equalToSuperview()
        }
        // 解绑按钮 - 左侧图标
        let unlinkImageView = UIImageView(image: UIImage(named: "reduser"))
        unlinkButton.addSubview(unlinkImageView)
        unlinkImageView.snp.makeConstraints { make in
            make.left.equalTo(11)
            make.centerY.equalToSuperview()
        }
        // 解绑按钮 - 左侧文字
        let unlinklabel = UILabel()
        unlinklabel.text = "Disconnect Partner"
        unlinklabel.textColor = .color(hexString: "#322D3A")
        unlinklabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        unlinkButton.addSubview(unlinklabel)
        unlinklabel.snp.makeConstraints { make in
            make.left.equalTo(unlinkImageView.snp.right).offset(5)
            make.centerY.equalToSuperview()
        }
        
        // 未连接时显示的「Add Partner」渐变按钮容器（放在页面最底部，与其他按钮布局一致）
        addPartnerContainerView = UIView()
        addPartnerContainerView.layer.cornerRadius = 18
        addPartnerContainerView.clipsToBounds = true
        view.addSubview(addPartnerContainerView)
        addPartnerContainerView.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
        linkContinueButton = UIButton(type: .system)
        linkContinueButton.setTitle("Add Partner", for: .normal)
        linkContinueButton.backgroundColor = .clear
        linkContinueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        linkContinueButton.setTitleColor(.white, for: .normal)
        linkContinueButton.addTarget(self, action: #selector(linkContinueButtonTapped), for: .touchUpInside)
        addPartnerContainerView.addSubview(linkContinueButton)
        linkContinueButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 根据连接状态显示 Unlink 或 Add Partner
        updateLinkUnlinkButtonVisibility()
        
        // 自身UUID（紧挨 Unlink 按钮下方）
        
        // ✅ 唯一的第一响应者，键盘为其弹出；文字同步到 accessory 的 nameInputTextField 仅作显示，避免第一响应者切到 accessory 内导致第三方键盘崩溃/双键盘
        hiddenTextField = UITextField()
        hiddenTextField.isHidden = true
        hiddenTextField.returnKeyType = .done
        hiddenTextField.enablesReturnKeyAutomatically = false
        hiddenTextField.delegate = self
        hiddenTextField.addTarget(self, action: #selector(hiddenTextFieldChanged), for: .editingChanged)
        view.addSubview(hiddenTextField)
        
        // ✅ 创建键盘上方的输入视图
        setupKeyboardInputView()
        
        // ✅ 添加点击背景区域收起键盘的手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:)))
        tapGesture.cancelsTouchesInView = false // ✅ 不影响其他控件的点击事件
        view.addGestureRecognizer(tapGesture)
        
        // ✅ 切换性别成功提示（与 Copy successful 同风格）
        switchSuccessView = UIView()
        switchSuccessView.layer.borderWidth = 1
        switchSuccessView.layer.borderColor = UIColor.color(hexString: "#E8E8E8").cgColor
        switchSuccessView.backgroundColor = .color(hexString: "#FFFFFF")
        switchSuccessView.layer.cornerRadius = 15
        switchSuccessView.isHidden = true
        view.addSubview(switchSuccessView)
        switchSuccessView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(30)
            switchSuccessBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-27).constraint
        }
        let switchSuccessImage = UIImageView(image: UIImage(named: "checkCircle"))
        switchSuccessView.addSubview(switchSuccessImage)
        switchSuccessImage.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(4)
        }
        let switchSuccessLabel = UILabel()
        switchSuccessLabel.text = "Switch successful"
        switchSuccessLabel.textColor = .color(hexString: "#8A8E9D")
        switchSuccessLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 14)
        switchSuccessView.addSubview(switchSuccessLabel)
        switchSuccessLabel.snp.makeConstraints { make in
            make.left.equalTo(switchSuccessImage.snp.right).offset(3)
            make.centerY.equalToSuperview()
            make.right.equalTo(-8)
        }
    }
    
    // MARK: - 数据加载
//    private func loadUUIDData() {
//        // 获取自己的UUID
//        let myUUID = UserManger.manager.currentUserUUID
//        myUUIDLabel.text = myUUID.isEmpty ? "未生成UUID" : myUUID
//        
//        // 获取伴侣的UUID
//        let (_, partnerUser) = UserManger.manager.getCoupleUsers()
//        var partnerUUID = partnerUser?.id ?? ""
//        // 兜底：空值/与自身UUID重复则显示未配对
//        if partnerUUID.isEmpty || partnerUUID == myUUID {
//            partnerUUIDLabel.text = "未配对/无有效伴侣"
//        } else {
//            partnerUUIDLabel.text = partnerUUID
//        }
//    }
    
    private func addNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleLinkStateDidChange),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoupleLinkStateDidChange),
            name: NSNotification.Name("CoupleDidLinkNotification"),
            object: nil
        )
    }
    
    @objc private func handleCoupleLinkStateDidChange() {
        updateLinkUnlinkButtonVisibility()
    }
    
    /// 根据连接状态显示 Unlink（已连接）或底部 Add Partner（未连接）
    private func updateLinkUnlinkButtonVisibility() {
        let isLinked = CoupleStatusManager.shared.isUserLinked
        unlinkButton.isHidden = !isLinked
        addPartnerContainerView.isHidden = isLinked
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 为 Add Partner 容器设置左上→右下渐变（#EC82FF → #6EB4FF）
        if addPartnerGradientLayer == nil, addPartnerContainerView.bounds.width > 0 {
            let layer = CAGradientLayer()
            layer.colors = [
                UIColor.color(hexString: "#EC82FF").cgColor,
                UIColor.color(hexString: "#6EB4FF").cgColor
            ]
            layer.startPoint = CGPoint(x: 0, y: 0)
            layer.endPoint = CGPoint(x: 1, y: 1)
            layer.cornerRadius = 18
            addPartnerContainerView.layer.insertSublayer(layer, at: 0)
            addPartnerGradientLayer = layer
        }
        addPartnerGradientLayer?.frame = addPartnerContainerView.bounds
    }
    
    // MARK: - 按钮点击事件
    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func genderButtonTapped() {
        // 加载当前性别
        let currentUUID = UserManger.manager.currentUserUUID
        if let userModel = UserManger.manager.getUserModelByUUID(currentUUID) {
            genderPopup.loadCurrentGender(userModel.gender)
        }
        // 性别选择回调
        genderPopup.onGenderSelected = { [weak self] gender in
            guard let self = self else { return }
            self.updateGender(gender)
        }
        genderPopup.show(width: view.width(), bottomSpacing: view.window?.safeAreaInsets.bottom ?? 34)
    }
    
    @objc func birthdayButtonTapped() {
        // 加载当前生日
        let currentUUID = UserManger.manager.currentUserUUID
        var initialBirthday: Date? = nil
        if let userModel = UserManger.manager.getUserModelByUUID(currentUUID), let birthday = userModel.birthday {
            initialBirthday = birthday
        }
        // 生日选择回调
        birthdayPopup.onDateSelected = { [weak self] selectedDate in
            guard let self = self else { return }
            self.updateBirthday(selectedDate)
        }
        birthdayPopup.show(width: view.width(), bottomSpacing: view.window?.safeAreaInsets.bottom ?? 34, initialDate: initialBirthday)
    }
    
    @objc func unlinkButtonTapped() {
        navigationController?.pushViewController(UnlinkViewController(), animated: true)
    }
    
    @objc func linkContinueButtonTapped() {
        let cheekVc = CheekBootPageView()
        cheekVc.isPresentedFromUnlink = true
        cheekVc.modalPresentationStyle = .fullScreen
        let nav = UINavigationController(rootViewController: cheekVc)
        nav.modalPresentationStyle = .fullScreen
        nav.setNavigationBarHidden(true, animated: false)
        present(nav, animated: true)
    }
    
    @objc func avatarButtonTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in
            self?.presentPicker(.camera)
        })
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPicker(.photoLibrary)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = avatarSelectButton
            pop.sourceRect = avatarSelectButton.bounds
        }
        present(alert, animated: true)
    }
    
    private func presentPicker(_ source: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else {
            AlertManager.showSingleButtonAlert(message: "Not available", target: self)
            return
        }
        let p = UIImagePickerController()
        p.sourceType = source
        p.delegate = self
        present(p, animated: true)
    }
    
    @objc func renameButtonTapped() {
        if isDismissingKeyboard { return }
        let currentName = toptext.text ?? ""
        let text = (currentName != "YourName" && !currentName.isEmpty) ? currentName : ""
        hiddenTextField.text = text
        nameInputTextField.text = text
        hiddenTextField.becomeFirstResponder()
    }

    @objc private func hiddenTextFieldChanged() {
        nameInputTextField.text = hiddenTextField.text
    }
    
    // MARK: - 业务逻辑处理
    // 更新性别
    private func updateGender(_ gender: String) {
        let currentUUID = UserManger.manager.currentUserUUID
        UserManger.manager.updateUserByUUID(uuid: currentUUID, gender: gender)
        print("[UserAvatar] 性别更新成功: \(gender)")
        
        // 更新UI显示
        if let genderValueLabel = genderButton.viewWithTag(1001) as? UILabel {
            genderValueLabel.text = gender
        }
        // 无自定义头像时，根据 GenderPopup 选择刷新默认头像
        loadUserAvatarAndName()
        // 显示 Switch successful 提示（与 Copy successful 同风格）
        showSwitchSuccessViewAndAutoDismiss()
    }
    
    /// 显示「Switch successful」提示并自动消失（与 Copy successful 同风格）
    /// 有底部按钮（Add Partner）时布局到按钮上方 16pt，否则使用 safeArea 底部 -27
    private func showSwitchSuccessViewAndAutoDismiss() {
        switchSuccessBottomConstraint?.deactivate()
        if addPartnerContainerView.isHidden {
            switchSuccessView.snp.makeConstraints { make in
                switchSuccessBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-27).constraint
            }
        } else {
            switchSuccessView.snp.makeConstraints { make in
                switchSuccessBottomConstraint = make.bottom.equalTo(addPartnerContainerView.snp.top).offset(-16).constraint
            }
        }
        
        switchSuccessView.isHidden = false
        switchSuccessView.alpha = 0.0
        UIView.animate(withDuration: 0.2) {
            self.switchSuccessView.alpha = 1.0
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5) {
                self.switchSuccessView.alpha = 0.0
            } completion: { _ in
                self.switchSuccessView.isHidden = true
            }
        }
    }
    
    // 更新生日
    private func updateBirthday(_ birthday: Date) {
        let currentUUID = UserManger.manager.currentUserUUID
        UserManger.manager.updateUserByUUID(uuid: currentUUID, birthday: birthday)
        print("[UserAvatar] 生日更新成功: \(birthday)")
        // 更新UI显示
        updateBirthdayDisplay(birthday)
    }
    
    // 更新生日显示格式
    private func updateBirthdayDisplay(_ birthday: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let birthdayText = dateFormatter.string(from: birthday)
        
        if let birthdayDateLabel = dataButton.viewWithTag(1002) as? UILabel {
            birthdayDateLabel.text = birthdayText
        }
    }
    
    // 更新用户名
    private func updateUserName(_ newName: String) {
        let currentUUID = UserManger.manager.currentUserUUID
        UserManger.manager.updateUserByUUID(uuid: currentUUID, userName: newName)
        // ✅ 更新显示（根据是否为默认值设置颜色）
        updateUserNameDisplay(newName, isDefault: false)
    }
    
    // ✅ 更新用户名显示（根据是否为默认值设置颜色）
    private func updateUserNameDisplay(_ name: String, isDefault: Bool) {
        // ✅ 先更新文本
        toptext.text = name
        toptextunderLabel.text = name
        toptextunderunderLabel.text = name
        
        // ✅ 如果是默认值或名字是"YourName"，使用灰色；否则使用黑色
        if isDefault || name == "YourName" {
            toptext.textColor = .color(hexString: "#8A8E9D")
        } else {
            toptext.textColor = .color(hexString: "#322D3A")
        }
    }
    
    // 加载用户头像和名称
    private func loadUserAvatarAndName() {
        let currentUUID = UserManger.manager.currentUserUUID
        guard let userModel = UserManger.manager.getUserModelByUUID(currentUUID) else {
            print("[UserAvatar] 警告：未找到当前用户模型")
            return
        }
        
        // ✅ 加载名称：如果设置了名字就显示名字，为空或YourName则显示YourName（灰色）
        if let userName = userModel.userName, !userName.isEmpty, userName != "YourName" {
            // ✅ 如果数据库中有名字（不为空且不是YourName），显示这个名字（黑色）
            updateUserNameDisplay(userName, isDefault: false)
        } else {
            // ✅ 如果数据库中没有名字、为空或是YourName，显示YourName（灰色）
            updateUserNameDisplay("YourName", isDefault: true)
        }
        
        // 加载性别
        if let genderValueLabel = genderButton.viewWithTag(1001) as? UILabel {
            // 优先从UserDefaults读取，无则从CoreData读取并同步
            var gender = CoupleStatusManager.shared.userGender
            if gender == nil || gender!.isEmpty {
                gender = userModel.gender
                if let genderFromCoreData = gender, !genderFromCoreData.isEmpty {
                    CoupleStatusManager.shared.userGender = genderFromCoreData
                }
            }
            genderValueLabel.text = gender?.isEmpty ?? true ? "未设置" : gender
        }
        
        // 加载生日
        if let birthday = userModel.birthday {
            updateBirthdayDisplay(birthday)
        }
        
        // 加载头像（Base64解码）；无头像时根据 GenderPopup 选择的性别显示默认头像（与引导页 SetView 一致）
        guard let avatarString = userModel.avatarImageURL, !avatarString.isEmpty else {
            let gender = userModel.gender ?? ""
            let defaultImageName: String
            if gender.lowercased() == "male" || gender.lowercased() == "男" {
                defaultImageName = "maleImageback"
            } else if gender.lowercased() == "female" || gender.lowercased() == "女" {
                defaultImageName = "femaleImageback"
            } else {
                defaultImageName = "userText"
            }
            avatarImageView.image = UIImage(named: defaultImageName) ?? UIImage(named: "userText")
            avatarImageView.contentMode = .scaleAspectFit
            avatarImageView.clipsToBounds = false
            avatarImageView.layer.cornerRadius = 0
            avatarImageView.layer.shadowOpacity = 0
            avatarImageView.applyAvatarCutoutShadow()
            return
        }
        
        // 默认占位图按性别（与无头像时一致）
        let genderForPlaceholder = userModel.gender ?? ""
        let placeholderImageName: String = {
            if genderForPlaceholder.lowercased() == "male" || genderForPlaceholder.lowercased() == "男" { return "maleImageback" }
            if genderForPlaceholder.lowercased() == "female" || genderForPlaceholder.lowercased() == "女" { return "femaleImageback" }
            return "userText"
        }()
        
        // 后台解码，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let image = self.imageFromBase64String(avatarString) else {
                DispatchQueue.main.async {
                    self.avatarImageView.image = UIImage(named: placeholderImageName) ?? UIImage(named: "userText")
                    self.avatarImageView.layer.shadowOpacity = 0
                }
                return
            }
            
            // AI抠图处理（仅1次）
            ImageProcessor.shared.processAvatarWithAICutout(image: image, borderWidth: 10, cacheKey: avatarString) { [weak self] processedImage in
                guard let self = self, self.isViewLoaded else { return }
                DispatchQueue.main.async {
                    // 显示处理后的头像，统一显示配置，自定义抠图头像应用阴影
                    self.avatarImageView.image = processedImage ?? image
                    self.avatarImageView.contentMode = .scaleAspectFit
                    self.avatarImageView.clipsToBounds = false
                    self.avatarImageView.layer.cornerRadius = 0
                    self.avatarImageView.applyAvatarCutoutShadow()
                }
            }
        }
    }
    
    /// 压缩图片至 maxMB 以内（与 BootAvatarSetupViewController 一致）
    private func compressImage(_ image: UIImage, maxMB: Double) -> Data? {
        let maxB = Int(maxMB * 1024 * 1024)
        var q: CGFloat = 0.8
        var img = image
        for _ in 0..<6 {
            if let d = img.jpegData(compressionQuality: q), d.count <= maxB { return d }
            q -= 0.12
        }
        for scale in stride(from: CGFloat(0.75), through: 0.35, by: -0.15) {
            let sz = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(sz, false, img.scale)
            img.draw(in: CGRect(origin: .zero, size: sz))
            if let scaled = UIGraphicsGetImageFromCurrentImageContext() {
                img = scaled
            }
            UIGraphicsEndImageContext()
            if let d = img.jpegData(compressionQuality: 0.5), d.count <= maxB { return d }
        }
        return img.jpegData(compressionQuality: 0.35)
    }
    
    // MARK: - 工具方法
    // Base64字符串转UIImage
    private func imageFromBase64String(_ base64String: String) -> UIImage? {
        var base64 = base64String
        // 移除data:image/前缀
        if base64.hasPrefix("data:image/") {
            guard let range = base64.range(of: ",") else { return nil }
            base64 = String(base64[range.upperBound...])
        }
        // 解码
        guard let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    // MARK: - UIImagePickerControllerDelegate（与 BootAvatarSetupViewController 一致）
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let img = info[.originalImage] as? UIImage,
              let data = compressImage(img, maxMB: 1) else {
            AlertManager.showSingleButtonAlert(message: "Image processing failed", target: self)
            return
        }
        ImageProcessor.shared.processAvatarWithAICutout(image: img, borderWidth: 10) { [weak self] processed in
            guard let self = self, self.isViewLoaded else { return }
            DispatchQueue.main.async {
                self.avatarImageView.image = processed ?? img
                self.avatarImageView.contentMode = .scaleAspectFit
                self.avatarImageView.clipsToBounds = false
                self.avatarImageView.layer.cornerRadius = 0
                self.avatarImageView.applyAvatarCutoutShadow()
                let b64 = "data:image/jpeg;base64,\(data.base64EncodedString())"
                UserManger.manager.updateAvatarURL(uuid: UserManger.manager.currentUserUUID, avatarURL: b64)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    // MARK: - 自定义输入框相关方法
    // ✅ 设置键盘上方的输入视图
    private func setupKeyboardInputView() {
        keyboardInputView = UIView()
        keyboardInputView.backgroundColor = .white
        
        let screenWidth = UIScreen.main.bounds.width
        keyboardInputView.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 60)
        keyboardInputView.autoresizingMask = [.flexibleWidth]
        
        // ✅ 输入框容器（已取消键盘上方 Done 按钮，仅保留输入栏）
        let inputContainerView = UIView()
        inputContainerView.backgroundColor = .color(hexString: "#F5F5F5")
        inputContainerView.layer.cornerRadius = 18
        keyboardInputView.addSubview(inputContainerView)
        
        inputContainerView.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
        }
        
        // ✅ 输入框（在 accessory 中仅作显示，真正输入在 hiddenTextField）
        nameInputTextField = UITextField()
        nameInputTextField.backgroundColor = .clear
        nameInputTextField.font = UIFont(name: "SFCompactRounded-Bold", size: 16)!
        nameInputTextField.textColor = .color(hexString: "#322D3A")
        nameInputTextField.isUserInteractionEnabled = false
        inputContainerView.addSubview(nameInputTextField)
        
        nameInputTextField.snp.makeConstraints { make in
            make.left.equalTo(15)
            make.right.equalTo(-15)
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
        }
        
        // ✅ 键盘上方的输入栏作为 hiddenTextField 的 accessory，hiddenTextField 在 window 内才能弹出键盘
        hiddenTextField.inputAccessoryView = keyboardInputView
    }
    
    // ✅ 点击背景区域收起键盘
    @objc func dismissKeyboard(_ gesture: UITapGestureRecognizer) {
        if hiddenTextField.isFirstResponder {
            isDismissingKeyboard = true
            hiddenTextField.resignFirstResponder()
            view.endEditing(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                self.isDismissingKeyboard = false
                let newName = self.hiddenTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !newName.isEmpty {
                    self.updateUserName(newName)
                } else {
                    let currentUUID = UserManger.manager.currentUserUUID
                    UserManger.manager.updateUserByUUID(uuid: currentUUID, userName: "")
                    self.updateUserNameDisplay("YourName", isDefault: true)
                }
                self.hiddenTextField.text = ""
                self.nameInputTextField.text = ""
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        hiddenTextField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === hiddenTextField, !isDismissingKeyboard {
            let newName = hiddenTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !newName.isEmpty {
                updateUserName(newName)
            } else {
                let currentUUID = UserManger.manager.currentUserUUID
                UserManger.manager.updateUserByUUID(uuid: currentUUID, userName: "")
                updateUserNameDisplay("YourName", isDefault: true)
            }
            hiddenTextField.text = ""
            nameInputTextField.text = ""
        }
    }
}
