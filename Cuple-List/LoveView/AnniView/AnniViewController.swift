//
//  AnniViewController.swift
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

struct AnniItem {
    let id: String
    let titlelabel: String
    let targetDate: Date
    let repeatDate: String
    let isNever: Bool
    let advanceDate: String
    let isReminder: Bool
    let assignIndex: Int
    let wishImage: String
}

class AnniViewController: UIViewController {
    var momentsLabel: UILabel!
    var underMomentsLabel: StrokeShadowLabel!
    var underunderMomentsLabel: StrokeShadowLabel!
    var anniModel: AnniModel?
    var annitems: [AnniItem] = []
    var titleLabelImage: UIImageView!
    var addButton: UIButton!
    var anniDatePopup = AnniDatePopup()
    var addAnniViewPopup = AddAnniViewPopup()
    var repeatViewPopup = RepeatPopup()
    var advancePopup = AdvancePopup()
    private var unlinkPopup: UnlinkConfirmPopup?
    var leftPinkView: UIView!
    var rightPinkView: UIView!
    var rightovertimeLabel: GradientMaskLabel!
    var rightunderovertimeLabel: StrokeShadowLabel!
    var rightunderunderovertimeLabel: StrokeShadowLabel!
    var leftovertimeLabel: GradientMaskLabel!
    var leftunderovertimeLabel: StrokeShadowLabel!
    var leftunderunderovertimeLabel: StrokeShadowLabel!
    var hiddenFirstTitleLabel: UILabel!
    var hiddenSecondTitleLabel: UILabel!
    var leftTargetLabel: UILabel!
    var rightTargetLabel: UILabel!
    var firstIamge: UILabel!
    var sencondImage: UILabel!
    let annitabelView = AnniTableViewController()
    
    // ✅ 防抖机制：避免频繁更新
    private var updateWorkItem: DispatchWorkItem?
    private var lastUpdateTime: Date = Date.distantPast
    private let updateDebounceInterval: TimeInterval = 0.5 // ✅ 防抖间隔：0.5秒
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // ✅ 修正执行顺序：UI初始化 → 代理赋值 → 通知注册 → 数据加载
        setUI()
        annitabelView.anniView = self
        annitabelView.editPopup.anniViewController = self
        fetchAndReloadItems()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCoreDataUpdate),
                                               name: AnniManger.dataDidUpdateNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMidnightRefresh),
                                               name: NSNotification.Name("AnniMidnightRefreshNotification"),
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCoupleDidUnlink),
                                               name: CoupleStatusManager.coupleDidUnlinkNotification,
                                               object: nil)
        
        annitabelView.refreshTableViewFilter()
    }
    
    @objc private func handleCoupleDidUnlink() {
        guard isViewLoaded else { return }
        
        print("🔔 AnniViewController: 收到断开链接通知，更新UI")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. 隐藏纪念日卡片
            self.hideLeftPinkView()
            self.hideRightPinkView()
            
            // 2. 刷新纪念日列表
            self.fetchAndReloadItems()
            self.annitabelView.refreshTableViewFilter()
            
            // 3. 显示空状态
            
            print("✅ AnniViewController: 断开链接UI更新完成")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHiddenTitlesDisplay()
    }
    
    func setUI() {
        view.backgroundColor = .white
        let gradientView = ViewGradientView()
        view.addSubview(gradientView)
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        underunderMomentsLabel = StrokeShadowLabel()
        underunderMomentsLabel.text = "Moments"
        underunderMomentsLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        underunderMomentsLabel.shadowOffset = CGSize(width: 0, height: 1)
        underunderMomentsLabel.shadowBlurRadius = 1.0
//        underunderdayLabel.letterSpacing = 16.0
        underunderMomentsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        view.addSubview(underunderMomentsLabel)
        underunderMomentsLabel.snp.makeConstraints { make in
            make.left.equalTo(17)
            make.topMargin.equalTo(21)
        }
        
        underMomentsLabel = StrokeShadowLabel()
        underMomentsLabel.text = "Moments"
        underMomentsLabel.shadowColor = UIColor.black.withAlphaComponent(0.01)
        underMomentsLabel.shadowOffset = CGSize(width: 0, height: 2)
        underMomentsLabel.shadowBlurRadius = 4.0
//        underdayLabel.letterSpacing = 16.0
        underMomentsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)!
        view.addSubview(underMomentsLabel)
        underMomentsLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderMomentsLabel)
        }
        
        momentsLabel = UILabel()
        momentsLabel.text = "Moments"
        momentsLabel.textColor = .color(hexString: "#322D3A")
        momentsLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        view.addSubview(momentsLabel)
        
        momentsLabel.snp.makeConstraints { make in
            make.center.equalTo(underunderMomentsLabel)
        }
       
        
        let wishBtnShadowContainer = UIView()
        wishBtnShadowContainer.isUserInteractionEnabled = true
        view.addSubview(wishBtnShadowContainer)
        wishBtnShadowContainer.snp.makeConstraints { make in
            make.right.equalTo(-24)
            make.centerY.equalTo(underunderMomentsLabel)
        }
        
        wishBtnShadowContainer.layer.shadowColor = UIColor.black.withAlphaComponent(0.05).cgColor
        wishBtnShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 1)
        wishBtnShadowContainer.layer.shadowRadius = 2.0
        wishBtnShadowContainer.layer.shadowOpacity = 1.0
        wishBtnShadowContainer.layer.shadowColor = UIColor.black.withAlphaComponent(0.03).cgColor
        wishBtnShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 1)
        wishBtnShadowContainer.layer.shadowRadius = 4.0
        wishBtnShadowContainer.layer.shadowOpacity = 1.0
        
        addButton = UIButton()
        addButton.layer.cornerRadius = 17
        addButton.layer.borderWidth = 3
        addButton.clipsToBounds = true
        addButton.layer.borderColor = UIColor.color(hexString: "#FFFFFF").cgColor
        addButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            // ✅ 模拟器直接进入，真机才检测链接
            #if targetEnvironment(simulator)
            let skipLinkCheck = true
            #else
            let skipLinkCheck = false
            #endif
            guard skipLinkCheck || CoupleStatusManager.shared.isUserLinked else {
                // ✅ 清除本地状态（如果之前有链接状态残留）
                CoupleStatusManager.shared.resetAllStatus()
                
                // ✅ 显示 unlinkpopimage 弹窗，然后从弹窗跳转到 CheekBootPageView
                // ✅ 保存为实例变量，避免被释放导致按钮失效
                self.unlinkPopup = UnlinkConfirmPopup(
                    title: "No partner added",
                    message: "Connect with a partner to create and assign \ntasks.",
                    imageName: "unlinkpopimage",
                    cancelTitle: "Cancel",
                    confirmTitle: "Link Companion",
                    confirmBlock: { [weak self] in
                        guard let self = self else { return }
                        // ✅ 清除引用，允许弹窗被释放
                        self.unlinkPopup = nil
                        // ✅ 点击 Link Companion 后，直接 present 到 CheekBootPageView
                        let cheekVc = CheekBootPageView()
                        cheekVc.modalPresentationStyle = .fullScreen
                        cheekVc.isPresentedFromUnlink = true
                        let nav = UINavigationController(rootViewController: cheekVc)
                        nav.modalPresentationStyle = .fullScreen
                        nav.setNavigationBarHidden(true, animated: false)
                        self.present(nav, animated: true)
                    },
                    cancelBlock: { [weak self] in
                        // ✅ 点击 Cancel，直接关闭弹窗，不做任何操作
                        print("✅ AnniViewController: 用户取消链接")
                        // ✅ 清除引用，允许弹窗被释放
                        self?.unlinkPopup = nil
                    }
                )
                self.unlinkPopup?.show()
                return
            }
            guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
            // ✅ 已链接，正常显示 addAnniViewPopup
            addAnniViewPopup.show(width: view.width(), bottomSpacing: self.bottomSpacing())
        }
        wishBtnShadowContainer.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let addView = AnniButtonGradientView()
        addView.layer.cornerRadius = 17
        addView.isUserInteractionEnabled = false
        addButton.addSubview(addView)
        addView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let addLabel = UILabel()
        addLabel.text = "Add"
        addLabel.font = UIFont(name: "SFCompactRounded-Heavy", size: 14)
        addLabel.textColor = .color(hexString: "#FFFFFF")
        addView.addSubview(addLabel)
        
        addLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalTo(25.5)
            make.right.equalTo(-25.5)
            make.top.equalTo(5.5)
            make.bottom.equalTo(-5.5)
        }
        
        leftPinkView = UIView()
        leftPinkView.layer.cornerRadius = 22
        leftPinkView.layer.borderWidth = 4
        leftPinkView.layer.borderColor = UIColor.white.cgColor
        leftPinkView.clipsToBounds = true
        view.addSubview(leftPinkView)
        
        leftPinkView.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(addLabel.snp.bottom).offset(26)
            make.width.equalToSuperview().multipliedBy(160.0 / 375.0)
            make.height.equalToSuperview().multipliedBy(152.0 / 812.0)
        }
        
        let pinkImageOne = UIImageView(image: .anniTitle)
        leftPinkView.addSubview(pinkImageOne)
        
        pinkImageOne.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        leftunderunderovertimeLabel = StrokeShadowLabel()
        leftunderunderovertimeLabel.text = "00000"
        leftunderunderovertimeLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        leftunderunderovertimeLabel.shadowOffset = CGSize(width: 0, height: 1)
        leftunderunderovertimeLabel.shadowBlurRadius = 1.0
        leftunderunderovertimeLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 32)!
        
        leftPinkView.addSubview(leftunderunderovertimeLabel)
        
        let pinkCardDayReserve: CGFloat = 52
        
        leftunderunderovertimeLabel.snp.makeConstraints { make in
            make.top.equalTo(13)
            make.left.equalTo(10)
            make.trailing.lessThanOrEqualTo(leftPinkView.snp.trailing).offset(-pinkCardDayReserve)
        }
        
        leftunderovertimeLabel = StrokeShadowLabel()
        leftunderovertimeLabel.text = "00000"
        leftunderovertimeLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        leftunderovertimeLabel.shadowOffset = CGSize(width: 0, height: 1)
        leftunderovertimeLabel.shadowBlurRadius = 5.0
        leftunderovertimeLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 32)!
        
        leftPinkView.addSubview(leftunderovertimeLabel)
        
        leftunderovertimeLabel.snp.makeConstraints { make in
            make.center.equalTo(leftunderunderovertimeLabel)
            make.width.equalTo(leftunderunderovertimeLabel)
            make.height.equalTo(leftunderunderovertimeLabel)
        }
        
        leftovertimeLabel = GradientMaskLabel()
        leftovertimeLabel.text = "00000"
        leftovertimeLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 32)!
        leftovertimeLabel.gradientStartColor = .color(hexString: "#B479FF")
        leftovertimeLabel.gradientEndColor = .color(hexString: "#FF88C4")
        leftPinkView.addSubview(leftovertimeLabel)
        
        leftovertimeLabel.snp.makeConstraints { make in
            make.center.equalTo(leftunderunderovertimeLabel)
            make.width.equalTo(leftunderunderovertimeLabel)
            make.height.equalTo(leftunderunderovertimeLabel)
        }
        
        let dayLabel = UILabel()
        dayLabel.text = "day"
        dayLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        dayLabel.textColor = .color(hexString: "#999DAB")
        leftPinkView.addSubview(dayLabel)
        
        dayLabel.snp.makeConstraints { make in
            make.left.equalTo(leftovertimeLabel.snp.right).offset(9)
            make.bottom.equalTo(leftovertimeLabel.snp.bottom).offset(-3)
        }
        
        hiddenFirstTitleLabel = UILabel()
        hiddenFirstTitleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        hiddenFirstTitleLabel.textColor = .color(hexString: "#322D3A")
        hiddenFirstTitleLabel.textAlignment = .left
        hiddenFirstTitleLabel.numberOfLines = 2
        hiddenFirstTitleLabel.isHidden = true
        leftPinkView.addSubview(hiddenFirstTitleLabel)
        
        
        
        leftTargetLabel = UILabel()
        leftTargetLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 12)
        leftTargetLabel.textColor = .color(hexString: "#999DAB")
        leftTargetLabel.numberOfLines = 2
        leftTargetLabel.textAlignment = .left
        leftPinkView.addSubview(leftTargetLabel)
        
        leftTargetLabel.snp.makeConstraints { make in
            make.left.equalTo(18)
//            make.left.equalTo(leftovertimeLabel.snp.left).offset(4)
            make.bottom.equalTo(-14)
        }
        
       
        
        firstIamge = UILabel()
        firstIamge.font = UIFont.systemFont(ofSize: 24)
        leftPinkView.addSubview(firstIamge)
        
        firstIamge.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.bottom.equalTo(-16)
        }
        hiddenFirstTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(leftunderunderovertimeLabel.snp.bottom).offset(20)
            make.left.equalTo(18)
            make.right.equalTo(-18)
            make.bottom.equalTo(firstIamge.snp.top).offset(-10)
        }
        
        rightPinkView = UIView()
        rightPinkView.layer.cornerRadius = 22
        rightPinkView.layer.borderWidth = 4
        rightPinkView.layer.borderColor = UIColor.white.cgColor
        rightPinkView.clipsToBounds = true
        view.addSubview(rightPinkView)
        
        rightPinkView.snp.makeConstraints { make in
            make.right.equalTo(-20)
            make.top.equalTo(addLabel.snp.bottom).offset(26)
            make.width.equalToSuperview().multipliedBy(160 / 375.0)
            make.height.equalToSuperview().multipliedBy(152.0 / 812.0)
        }
        
        let pinkImageTwo = UIImageView(image: .anniTitle)
        rightPinkView.addSubview(pinkImageTwo)
        
        pinkImageTwo.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        rightunderunderovertimeLabel = StrokeShadowLabel()
        rightunderunderovertimeLabel.text = "00000"
        rightunderunderovertimeLabel.shadowColor = UIColor.black.withAlphaComponent(0.05)
        rightunderunderovertimeLabel.shadowOffset = CGSize(width: 0, height: 1)
        rightunderunderovertimeLabel.shadowBlurRadius = 1.0
        rightunderunderovertimeLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 32)!
        
        rightPinkView.addSubview(rightunderunderovertimeLabel)
        
        rightunderunderovertimeLabel.snp.makeConstraints { make in
            make.top.equalTo(13)
            make.left.equalTo(10)
            make.trailing.lessThanOrEqualTo(rightPinkView.snp.trailing).offset(-pinkCardDayReserve)
        }
        
        rightunderovertimeLabel = StrokeShadowLabel()
        rightunderovertimeLabel.text = "00000"
        rightunderovertimeLabel.shadowColor = UIColor.black.withAlphaComponent(0.1)
        rightunderovertimeLabel.shadowOffset = CGSize(width: 0, height: 1)
        rightunderovertimeLabel.shadowBlurRadius = 5.0
        rightunderovertimeLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 32)!
        
        rightPinkView.addSubview(rightunderovertimeLabel)
        
        rightunderovertimeLabel.snp.makeConstraints { make in
            make.center.equalTo(rightunderunderovertimeLabel)
            make.width.equalTo(rightunderunderovertimeLabel)
            make.height.equalTo(rightunderunderovertimeLabel)
        }
        
        rightovertimeLabel = GradientMaskLabel()
        rightovertimeLabel.text = "00000"
        rightovertimeLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 32)!
        rightovertimeLabel.gradientStartColor = .color(hexString: "#B479FF")
        rightovertimeLabel.gradientEndColor = .color(hexString: "#FF88C4")
        rightPinkView.addSubview(rightovertimeLabel)
        
        rightovertimeLabel.snp.makeConstraints { make in
            make.center.equalTo(rightunderunderovertimeLabel)
            make.width.equalTo(rightunderunderovertimeLabel)
            make.height.equalTo(rightunderunderovertimeLabel)
        }
        
        let dayLabel1 = UILabel()
        dayLabel1.text = "day"
        dayLabel1.font = UIFont(name: "SFCompactRounded-Medium", size: 13)
        dayLabel1.textColor = .color(hexString: "#999DAB")
        rightPinkView.addSubview(dayLabel1)
        
        dayLabel1.snp.makeConstraints { make in
            make.left.equalTo(rightovertimeLabel.snp.right).offset(9)
            make.bottom.equalTo(rightovertimeLabel.snp.bottom).offset(-3)
        }
        
        hiddenSecondTitleLabel = UILabel()
        hiddenSecondTitleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        hiddenSecondTitleLabel.textColor = .color(hexString: "#322D3A")
        hiddenSecondTitleLabel.textAlignment = .left
        hiddenSecondTitleLabel.numberOfLines = 2
        hiddenSecondTitleLabel.isHidden = true
        rightPinkView.addSubview(hiddenSecondTitleLabel)
        
        
        
        rightTargetLabel = UILabel()
        rightTargetLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 12)
        rightTargetLabel.textColor = .color(hexString: "#999DAB")
        rightTargetLabel.numberOfLines = 2
        rightTargetLabel.textAlignment = .left
        rightPinkView.addSubview(rightTargetLabel)
        
        rightTargetLabel.snp.makeConstraints { make in
            make.left.equalTo(18)
            make.bottom.equalTo(-14)
        }
        
       
        
        sencondImage = UILabel()
        sencondImage.font = UIFont.systemFont(ofSize: 24)
        rightPinkView.addSubview(sencondImage)
        
        sencondImage.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.bottom.equalTo(-16)
        }
        
        hiddenSecondTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(leftunderunderovertimeLabel.snp.bottom).offset(20)
            make.left.equalTo(18)
            make.right.equalTo(-18)
            make.bottom.equalTo(sencondImage.snp.top).offset(-10)
        }
        
        self.addChild(annitabelView)
        view.addSubview(annitabelView.view)
        
        let tabBarTopInset = (tabBarController as? MomoTabBarController)?.tabBarTopInsetFromBottom() ?? 49
        annitabelView.view.snp.makeConstraints { make in
            make.top.equalTo(rightPinkView.snp.bottom).offset(17)
            make.width.equalToSuperview()
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.snp.bottom).offset(-tabBarTopInset)
        }
        
        annitabelView.didMove(toParent: self)
        
        leftPinkView.isUserInteractionEnabled = true
        let leftTapGesture = UITapGestureRecognizer(target: self, action: #selector(leftPinkViewTapped))
        leftPinkView.addGestureRecognizer(leftTapGesture)
        
        rightPinkView.isUserInteractionEnabled = true
        let rightTapGesture = UITapGestureRecognizer(target: self, action: #selector(rightPinkViewTapped))
        rightPinkView.addGestureRecognizer(rightTapGesture)
        
        addAnniViewPopup.anniViewController = self
        anniDatePopup.homeViewController1 = self
        repeatViewPopup.homeViewController1 = self
    }
    
    @objc private func leftPinkViewTapped() {
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        let allModels = annitabelView.getAllSortedModels()
        guard let firstModel = allModels.first else { return }
        presentAnniEditPopup(for: firstModel)
    }
    
    @objc private func rightPinkViewTapped() {
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        let allModels = annitabelView.getAllSortedModels()
        guard allModels.count >= 2 else { return }
        presentAnniEditPopup(for: allModels[1])
    }
    
    /// 打开纪念日编辑弹窗（顶部卡片与列表共用）
    func presentAnniEditPopup(for model: AnniModel) {
        annitabelView.editPopup.onEditAndCloseComplete = nil
        annitabelView.editPopup.configureUI(with: model)
        annitabelView.editPopup.onEditComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.fetchAndReloadItems()
                self?.annitabelView.refreshTableViewFilter()
            }
        }
        annitabelView.editPopup.onDeleteComplete = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.fetchAndReloadItems()
                self?.annitabelView.refreshTableViewFilter()
            }
        }
        annitabelView.editPopup.show(width: view.width(), bottomSpacing: view.window?.safeAreaInsets.bottom ?? 34)
    }
    
    func fetchAndReloadItems() {
        let AnniModels = AnniManger.manager.fetchAnniModels()
        
        self.annitems = AnniModels
            .compactMap { model -> AnniItem? in
                guard let id = model.id else { return nil }
                
                return AnniItem(id: id,
                                titlelabel: model.titleLabel ?? "",
                                targetDate: model.targetDate ?? Date.distantPast,
                                repeatDate: model.repeatDate ?? "",
                                isNever: model.isNever,
                                advanceDate: model.advanceDate ?? "",
                                isReminder: model.isReminder,
                                assignIndex: Int(model.assignIndex),
                                wishImage: model.wishImage ?? "")
            }
            .sorted(by: { $0.targetDate.compare($1.targetDate) == .orderedDescending })
    }
    
    @objc func handleCoreDataUpdate() {
        // ✅ 防抖机制：避免频繁更新导致卡顿
        updateWorkItem?.cancel()
        
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
        
        // ✅ 如果距离上次更新不到防抖间隔，延迟执行（但不超过1秒）
        let delay: TimeInterval = timeSinceLastUpdate < updateDebounceInterval ? min(updateDebounceInterval - timeSinceLastUpdate, 1.0) : 0
        
        updateWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lastUpdateTime = Date()
            self.fetchAndReloadItems()
            self.annitabelView.refreshTableViewFilter()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: updateWorkItem!)
    }
    
    @objc private func handleMidnightRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.annitabelView.refreshTableViewFilter()
        }
    }
    
    func addAnniItem(
        titleLabel: String,
        targetDate: Date,
        repeatDate: String,
        isNever: Bool,
        advanceDate: String,
        isReminder: Bool,
        assignIndex: Int,
        imageURLs: [String], // ✅ 接收图片 URL 数组（Base64 字符串数组）
        wishImage: String,
        isShared: Bool
    ) {
        guard let addModel = AnniManger.manager.addModel(titleLabel: titleLabel,
                                                         targetDate: targetDate,
                                                         repeatDate: repeatDate,
                                                         isNever: isNever,
                                                         advanceDate: advanceDate,
                                                         isReminder: isReminder,
                                                         assignIndex: Int(assignIndex),
                                                         imageURLs: imageURLs, // ✅ 传递图片 URL 数组
                                                         wishImage: wishImage,
                                                         isShared: isShared
        ) else {
            print("❌ Failed to save item to Core Data.")
            return
        }
        
        // ✅ 只保存到 CoreData，由 CoreData 变更监听器自动同步到 Firebase
        // CoreData 变更监听器会自动将数据同步到 Firebase
        self.fetchAndReloadItems()
        self.annitabelView.refreshTableViewFilter()
    }
    
    // MARK: ✅ 顶部左侧卡片赋值（适配重复逻辑）
    func configureLeftPinkView(with model: AnniModel) {
        hiddenFirstTitleLabel.text = model.titleLabel ?? "未命名"
        firstIamge.text = model.wishImage
        guard model.targetDate != nil else { return }
        
        let finalDate = getFinalTargetDate(for: model)
        // ✅ 使用绝对天数计算
        let absDays = AnniDateCalculator.shared.calculateAbsDaysInterval(targetDate: finalDate)
        let daysText = AnniDateCalculator.shared.formatDays(absDays)
        
        leftunderovertimeLabel.text = daysText
        leftunderunderovertimeLabel.text = daysText
        leftovertimeLabel.text = daysText
        leftTargetLabel.text = "\(getDatePrefix(for: finalDate))\n\(AnniViewController.dateFormatter.string(from: finalDate))"
        
        hiddenFirstTitleLabel.isHidden = false
        leftPinkView.isHidden = false
        finishPinkCardNumberLayout(leftPinkView, numberViews: [
            leftunderunderovertimeLabel, leftunderovertimeLabel, leftovertimeLabel
        ])
    }
    
    // MARK: ✅ 顶部右侧卡片赋值（适配重复逻辑）
    func configureRightPinkView(with model: AnniModel) {
        hiddenSecondTitleLabel.text = model.titleLabel ?? "未命名"
        sencondImage.text = model.wishImage
        guard model.targetDate != nil else { return }
        
        let finalDate = getFinalTargetDate(for: model)
        // ✅ 使用绝对天数计算
        let absDays = AnniDateCalculator.shared.calculateAbsDaysInterval(targetDate: finalDate)
        let daysText = AnniDateCalculator.shared.formatDays(absDays)
        
        rightunderovertimeLabel.text = daysText
        rightunderunderovertimeLabel.text = daysText
        rightovertimeLabel.text = daysText
        rightTargetLabel.text = "\(getDatePrefix(for: finalDate))\n\(AnniViewController.dateFormatter.string(from: finalDate))"
        
        hiddenSecondTitleLabel.isHidden = false
        rightPinkView.isHidden = false
        finishPinkCardNumberLayout(rightPinkView, numberViews: [
            rightunderunderovertimeLabel, rightunderovertimeLabel, rightovertimeLabel
        ])
    }
    
    // MARK: ✅ 日期前缀（未来/当天/已过期）
    private func getDatePrefix(for targetDate: Date) -> String {
        let current = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: targetDate)
        let cmp = Calendar.current.compare(target, to: current, toGranularity: .day)
        
        switch cmp {
        case .orderedAscending: return "Start Date"
        case .orderedDescending: return "Target Date"
        case .orderedSame: return "Today"
        @unknown default: return "Date"
        }
    }
    
    // MARK: ✅ 计算模型最终目标日期（原始/下次重复）
    private func getFinalTargetDate(for model: AnniModel) -> Date {
        guard let originalDate = model.targetDate,
              let repeatText = model.repeatDate,
              repeatText != "Never" else {
            return model.targetDate ?? Date()
        }
        return AnniDateCalculator.shared.calculateNextTargetDate(originalDate: originalDate, repeatText: repeatText)
    }
    
    func hideLeftPinkView() {
        hiddenFirstTitleLabel.isHidden = true
        firstIamge.text = nil
        leftPinkView.isHidden = true
    }
    
    func hideRightPinkView() {
        hiddenSecondTitleLabel.isHidden = true
        sencondImage.text = nil
        rightPinkView.isHidden = true
    }
    
    private func getDateIntervalDescription(targetDate: Date, isPast: Bool) -> String {
        let currentDate = Date()
        let calendar = Calendar.current
        
        guard let daysInterval = calendar.dateComponents([.day], from: calendar.startOfDay(for: targetDate), to: calendar.startOfDay(for: currentDate)).day else {
            return "000"
        }
        
        let absoluteDays = abs(daysInterval)
        return String(format: "%03d", absoluteDays)
    }
    
    /// 粉卡天数文案变更后：刷新 intrinsic 并立即完成布局，避免刚添加/刚显示时仍沿用旧约束尺寸
    private func finishPinkCardNumberLayout(_ pinkView: UIView, numberViews: [UIView]) {
        guard !pinkView.isHidden else { return }
        numberViews.forEach {
            $0.invalidateIntrinsicContentSize()
            $0.setNeedsLayout()
        }
        pinkView.setNeedsLayout()
        pinkView.layoutIfNeeded()
    }
    
    private func updateHiddenTitlesDisplay() {
        let allModels = annitabelView.getAllSortedModels()
        let tableCount = annitabelView.fetchedResultsController.fetchedObjects?.count ?? 0
        let totalCount = allModels.count
        
        leftPinkView.isHidden = allModels.first == nil
        rightPinkView.isHidden = allModels.count < 2
        
        if let firstModel = allModels.first {
            configureLeftPinkView(with: firstModel)
        } else {
            hideLeftPinkView()
        }
        
        if allModels.count >= 2 {
            configureRightPinkView(with: allModels[1])
        } else {
            hideRightPinkView()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // ✅ 取消待执行的更新任务
        updateWorkItem?.cancel()
    }
}
