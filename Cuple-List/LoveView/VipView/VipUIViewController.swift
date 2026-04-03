//
//  VipUIViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import StoreKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit
import RevenueCat
import Lottie

class VipUIViewController: UIViewController, UIScrollViewDelegate {
    
    var restoreButton: UIButton!
    var closeButton: UIButton!
    var privacyButton: UIButton!
    var termsButton: UIButton!
    var middleUserImage: UIImageView!
    
    var longImageView: UIImageView!
    private var imageScrollView: UIScrollView!
    private var imageScrollViewLeftConstraint: Constraint?
    private var imageScrollViewRightConstraint: Constraint?
    private var imageScrollEdgeState: Int = 0 // 0=左, 1=中, 2=右，避免重复更新
    private let imageHeight: CGFloat = 100
    
    var yearlyProductView: ProductView!
    var weeklyProductView: ProductView!
    var verticalStackView: UIStackView!
    
    private var mainScrollView: UIScrollView!
    private var contentView: UIView!
    private var bottomContainer: UIView!
    
    var yearlyProduct: StoreProduct?
    var weeklyProduct: StoreProduct?
    
    var conButton: UIButton!
    var autoLabel: UILabel!
    private var buttonGlowLottieView: LottieAnimationView?
    
    var handler: (() -> Void)?
    
    var selectedIndex = 0  // 0: weekly, 1: yearly
    let scanFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    private let privacyPolicyURL = "https://docs.couplelist.omicost.cn/privacy"
    private let termsOfUseURL = "https://docs.couplelist.omicost.cn/terms"
    
    /// 由导航栈 push 进入（如引导页），关闭按钮用 arrow 并 pop；modal 进入用 listback 并 dismiss
    private var isPushedOntoNavigationStack: Bool {
        guard let nav = navigationController,
              nav.viewControllers.count > 1,
              let idx = nav.viewControllers.firstIndex(of: self),
              idx > 0 else { return false }
        return true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 全屏 modal 已盖住 TabBar，再执行隐藏会触发 TabBarController 整链布局与安全区刷新，
        // 易造成首帧与稳定帧不一致，表现为订阅页「刚进入整体上移」。
        guard isPushedOntoNavigationStack,
              let tabBarController = self.tabBarController as? MomoTabBarController else { return }
        tabBarController.simulationTabBar?.isHidden = true
        if tabBarController.simulationTabBar == nil {
            tabBarController.tabBar.isHidden = true
            tabBarController.homeAddButton?.isHidden = true
        }
        tabBarController.tabBar.isUserInteractionEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 未完成首次引导时：pop 顺序是「下方页 viewWillAppear」先于「本页 viewWillDisappear」。
        // 若在此处恢复 TabBar，会盖住引导页刚设的隐藏；且交互式侧滑返回时 isMovingFromParent 常为 false。
        if isPushedOntoNavigationStack, !UserDefaults.standard.bool(forKey: "hasLaunchedOnce") {
            return
        }
        guard isPushedOntoNavigationStack,
              let tabBarController = self.tabBarController as? MomoTabBarController else { return }
        tabBarController.simulationTabBar?.isHidden = false
        if tabBarController.simulationTabBar == nil {
            tabBarController.tabBar.isHidden = false
            tabBarController.homeAddButton?.isHidden = false
        }
        tabBarController.tabBar.isUserInteractionEnabled = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        
        if Purchases.isConfigured {
            requestProducts()
        } else {
            print("⚠️ VipUIViewController: RevenueCat 未初始化，延迟 0.5 秒后重试")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if Purchases.isConfigured {
                    self?.requestProducts()
                } else {
                    print("❌ VipUIViewController: RevenueCat 仍未初始化，显示错误")
                    self?.subscriptionProductsDidReciveFailure()
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 每次布局后确保底部容器在最上层，防止滚动内容覆盖底部图片
        if let bottom = bottomContainer {
            view.bringSubviewToFront(bottom)
        }
    }
    
    func configure() {
        view.backgroundColor = .white
        // viewDidLoad 时 view.bounds / safeArea 可能尚未稳定，比例用屏幕高（与 ProductView 一致），
        // 底部用 safeAreaLayoutGuide，避免首帧用错 inset 导致布局跳变。
        let layoutH = UIScreen.main.bounds.height
        
        bottomContainer = UIView()
        bottomContainer.backgroundColor = .clear
        
        view.addSubview(bottomContainer)
        bottomContainer.snp.makeConstraints { make in
            make.height.equalToSuperview().multipliedBy(140.0 / 812.0)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(-bottomSpacing())
        }
        
        let backiiii = UIImageView(image: .bottomback)
        bottomContainer.addSubview(backiiii)
        backiiii.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Continue 上方的文本
        let agreeLabel = UILabel()
        agreeLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 12)
        agreeLabel.text = "Auto Renewable, Cancel anytime"
        agreeLabel.textColor = .color(hexString: "#111111")
        agreeLabel.textAlignment = .center
        bottomContainer.addSubview(agreeLabel)
        agreeLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(20)
        }
        
        // Continue 按钮
        conButton = UIButton()
        conButton.backgroundColor = .color(hexString: "#111111")
        conButton.layer.cornerRadius = 18
        conButton.setTitle("Continue", for: .normal)
        conButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        conButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        conButton.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
            guard let self = self else { return }
            let product = self.selectedIndex == 0 ? self.weeklyProduct : self.yearlyProduct
            if let product = product {
                self.purchase(product: product)
            }
        }
        bottomContainer.addSubview(conButton)
        conButton.snp.makeConstraints { make in
            make.left.equalTo(24)
            make.right.equalTo(-24)
            make.height.equalTo(52)
            make.top.equalTo(agreeLabel.snp.bottom).offset(12)
        }
        conButton.clipsToBounds = true
        setupButtonGlowAnimation()
        
        // Terms of Use + Privacy Policy 按钮
        let linksStack = UIStackView()
        linksStack.axis = .horizontal
        linksStack.distribution = .fillEqually
        linksStack.spacing = 16
        
        termsButton = UIButton(type: .system)
        termsButton.setTitle("Terms of Use", for: .normal)
        termsButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Medium", size: 11)
        termsButton.setTitleColor(.color(hexString: "#8A8E9D"), for: .normal)
        termsButton.addTarget(self, action: #selector(termsButtonTapped), for: .touchUpInside)
        
        privacyButton = UIButton(type: .system)
        privacyButton.setTitle("Privacy Policy", for: .normal)
        privacyButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Medium", size: 11)
        privacyButton.setTitleColor(.color(hexString: "#8A8E9D"), for: .normal)
        privacyButton.addTarget(self, action: #selector(privacyButtonTapped), for: .touchUpInside)
        
        linksStack.addArrangedSubview(termsButton)
        linksStack.addArrangedSubview(privacyButton)
        bottomContainer.addSubview(linksStack)
        linksStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(conButton.snp.bottom).offset(4)
        }
        
        // 竖线：放在 linksStack 上方，避免影响按钮布局
        let separatorLine = UIView()
        separatorLine.backgroundColor = .color(hexString: "#8A8E9D")
        bottomContainer.addSubview(separatorLine)
        separatorLine.snp.makeConstraints { make in
            make.width.equalTo(1)
            make.height.equalTo(12)
            make.centerX.equalToSuperview()
            make.centerY.equalTo(linksStack)
        }
        
        // 主滚动区域（底部在 bottomContainer 上方）
        mainScrollView = UIScrollView()
        mainScrollView.showsVerticalScrollIndicator = true
        mainScrollView.alwaysBounceVertical = false
        mainScrollView.bounces = false
        mainScrollView.showsVerticalScrollIndicator = false
        mainScrollView.showsHorizontalScrollIndicator = false
        // 与 make.top(-topSpacing()) 全屏顶对齐叠加时，系统再自动塞 safeArea 会在最上方留出一条「填不满」的空白
        mainScrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(mainScrollView)
        mainScrollView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview()
            make.bottom.equalTo(bottomContainer.snp.bottom)
        }
        
        contentView = UIView()
        contentView.backgroundColor = .clear
        mainScrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(mainScrollView.contentLayoutGuide)
            make.width.equalTo(mainScrollView.frameLayoutGuide)
        }
        
        let contentGradientBackground = VipScrollContentGradientView()
        contentView.addSubview(contentGradientBackground)
        contentGradientBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let inView1 = UIImageView(image: .pointback)
//        inView1.contentMode = .scaleAspectFill
        contentView.addSubview(inView1)
        inView1.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
        }
       
//        let xxx40 = view.height() * 15.0 / 812.0
        let inView = UIImageView(image: .clearback)
//                inView.contentMode = .scaleAspectFill
        //        inView.clipsToBounds = true
        contentView.addSubview(inView)
        inView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(inView.snp.width)
        }
        
        
        let xxx24 = layoutH * 24.0 / 812.0
        
        // 顶部固定：Back + Restore（push 进入时与引导页一致用 arrow）
        closeButton = UIButton()
        closeButton.setImage(UIImage(named: isPushedOntoNavigationStack ? "arrow" : "listback"), for: .normal)
        closeButton.addTarget(self, action: #selector(handleLimitedLabelTap), for: .touchUpInside)
        contentView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.left.equalTo(24)
            make.topMargin.equalTo(xxx24)
        }
        
        restoreButton = UIButton()
        restoreButton.setTitle("Restore", for: .normal)
        restoreButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Regular", size: 15)
        restoreButton.setTitleColor(.color(hexString: "#999DAB"), for: .normal)
        restoreButton.addTarget(self, action: #selector(restoreButtonTapped), for: .touchUpInside)
        contentView.addSubview(restoreButton)
//        let xxx79 = view.height() * 79.0 / 812.0
        restoreButton.snp.makeConstraints { make in
            make.right.equalTo(-24)
            make.centerY.equalTo(closeButton)
//            make.top.equalTo(xxx79)
        }
        
//        var lastView: UIView?
        let xxx25 = layoutH * 25 / 812.0
        // 1. 中间图片 + 标题
        middleUserImage = UIImageView(image: .vipMiddle)
        middleUserImage.contentMode = .scaleAspectFit  // 不拉伸，保持比例
        contentView.addSubview(middleUserImage)
        middleUserImage.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(inView).offset(xxx25)
            make.width.equalToSuperview().multipliedBy(186.6 / 375.0)
            make.height.equalTo(middleUserImage.snp.width).multipliedBy(146.25 / 181.0)
        }
//        lastView = middleUserImage
        
        let unlockLabel = UILabel()
        unlockLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 28)
        unlockLabel.numberOfLines = 0
        unlockLabel.text = "Make every moment together count"
        unlockLabel.textColor = .color(hexString: "#000000")
        unlockLabel.textAlignment = .center
        contentView.addSubview(unlockLabel)
        unlockLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(middleUserImage.snp.bottom).offset(21)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
//        lastView = unlockLabel
        
        // 2. 两个上下选中按钮：周订阅、年订阅
        weeklyProductView = ProductView()
        weeklyProductView.showMostPopularBadgeWhenSelected = true
        weeklyProductView.setSelected(true)
        weeklyProductView.set(priceString: "then $4.99 per week", time: "3-Day Free Trial", rightTimeLabel: "$4.99/week")
        weeklyProductView.pipe.output.observeValues { [weak self] _ in
            guard let self = self else { return }
            self.scanFeedbackGenerator.impactOccurred()
            self.scanFeedbackGenerator.prepare()
            self.selectedIndex = 0
            self.weeklyProductView.setSelected(true)
            self.yearlyProductView.setSelected(false)
        }
        contentView.addSubview(weeklyProductView)
        weeklyProductView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(unlockLabel.snp.bottom).offset(37)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(weeklyProductView.snp.width).multipliedBy(60.0 / 335.0)
        }
        
        yearlyProductView = ProductView()
        yearlyProductView.setSelected(false)
        yearlyProductView.set(priceString: "$29.99 per year", time: "Yearly", rightTimeLabel: "$0.57/week")
        yearlyProductView.pipe.output.observeValues { [weak self] _ in
            guard let self = self else { return }
            self.scanFeedbackGenerator.impactOccurred()
            self.scanFeedbackGenerator.prepare()
            self.selectedIndex = 1
            self.weeklyProductView.setSelected(false)
            self.yearlyProductView.setSelected(true)
        }
        contentView.addSubview(yearlyProductView)
        yearlyProductView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(weeklyProductView.snp.bottom).offset(18)
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(weeklyProductView.snp.width).multipliedBy(60.0 / 335.0)
        }
//        lastView = yearlyProductView
        
        let featureBgView = UIView()
        featureBgView.backgroundColor = .color(hexString: "#E5ECFF").withAlphaComponent(0.2)
        featureBgView.layer.borderWidth = 1
        featureBgView.layer.borderColor = UIColor.color(hexString: "#E5ECFF").cgColor
        featureBgView.layer.cornerRadius = 16
        contentView.addSubview(featureBgView)
        featureBgView.snp.makeConstraints { make in
            make.top.equalTo(yearlyProductView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(layoutH * 172.0 / 812.0)
        }
        // 3. 4 行带头部图片的文本
        let item1 = GreenLabelView()
        item1.configure(image: UIImage(named: "e1vip1"), text: "Connect and share with your partner")
        let item2 = GreenLabelView()
        item2.configure(image: UIImage(named: "e1vip2"), text: "Create tasks together for everyday life")
        let item3 = GreenLabelView()
        item3.configure(image: UIImage(named: "e1vip3"), text: "Set reminders for the things that matter")
        let item4 = GreenLabelView()
        item4.configure(image: UIImage(named: "e1vip4"), text: "Never miss an anniversary or special moment")
        
        verticalStackView = UIStackView(arrangedSubviews: [item1, item2, item3, item4])
        verticalStackView.axis = .vertical
        verticalStackView.distribution = .fillEqually
        verticalStackView.alignment = .leading
//        verticalStackView.spacing = view.height() * 3.0 / 812.0
        featureBgView.addSubview(verticalStackView)
        verticalStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(5)
            make.edges.equalToSuperview()
        }
//        lastView = verticalStackView
        
        // 3.5 E5ECFF 背景区域 (335*172)
        
        
        // 4. 滑动图片（不循环，最左边时左20，最右边时右20，中间两边0）
        setupLoopScrollImage()
        imageScrollView.snp.makeConstraints { make in
            make.top.equalTo(featureBgView.snp.bottom).offset(25)
            imageScrollViewLeftConstraint = make.left.equalToSuperview().offset(20).constraint
            imageScrollViewRightConstraint = make.right.equalToSuperview().constraint
            make.height.equalTo(imageHeight)
        }
//        lastView = imageScrollView
        
        // 5. 长文字
        let longTextLabel = UILabel()
        longTextLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 12)
        longTextLabel.textColor = .color(hexString: "#999DAB")
        longTextLabel.numberOfLines = 0
        longTextLabel.text = """
        Payment will be charged to your Apple ID account at confirmation of purchase.You can manage or turn off auto-renewal at any time in your App Store account settings.
        
        If you do not wish to renew, please turn off auto-renewal at least 24 hours before the end of the current billing period. Otherwise, the subscription will automatically renew.
        """
        contentView.addSubview(longTextLabel)
        longTextLabel.snp.makeConstraints { make in
            make.top.equalTo(imageScrollView.snp.bottom).offset(25)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            let bottonView = layoutH * 140.0 / 812.0
//            let bottonView = bottomContainer.snp.height
            make.bottom.equalToSuperview().offset(-bottonView)
        }
    }
    
    private func setupButtonGlowAnimation() {
        let animName = "按钮光效"
        if let animation = (try? LottieAnimation.named("Tools/\(animName)")) ?? (try? LottieAnimation.named(animName)) {
            buttonGlowLottieView = LottieAnimationView(animation: animation)
            buttonGlowLottieView?.loopMode = .loop
            buttonGlowLottieView?.contentMode = .scaleAspectFill
            buttonGlowLottieView?.backgroundBehavior = .pauseAndRestore
            buttonGlowLottieView?.isUserInteractionEnabled = false
//            buttonGlowLottieView?.alpha = 0.75
            if let lottie = buttonGlowLottieView {
                conButton.insertSubview(lottie, at: 0)
                lottie.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
//                let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
//                blurView.isUserInteractionEnabled = false
//                blurView.alpha = 0.5
//                conButton.insertSubview(blurView, at: 1)
//                blurView.snp.makeConstraints { make in
//                    make.edges.equalToSuperview()
//                }
                lottie.play()
            }
        }
    }
    
    private func setupLoopScrollImage() {
        guard let image = UIImage(named: "longImageView") else {
            print("⚠️ 长图片资源不存在，请检查图片名称 'longImageView'")
            return
        }
        let imageWidth = image.size.width
        
        imageScrollView = UIScrollView()
        imageScrollView.showsHorizontalScrollIndicator = false
        imageScrollView.showsVerticalScrollIndicator = false
        imageScrollView.bounces = false
        imageScrollView.delegate = self
        contentView.addSubview(imageScrollView)
        
        longImageView = UIImageView(image: image)
        longImageView.contentMode = .scaleToFill
        longImageView.clipsToBounds = true
        imageScrollView.addSubview(longImageView)
        
        longImageView.snp.makeConstraints { make in
            make.edges.equalTo(imageScrollView)
            make.width.equalTo(imageWidth)
            make.height.equalTo(imageHeight)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.imageScrollView.setContentOffset(.zero, animated: false)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView == imageScrollView, !decelerate else { return }
        updateImageScrollEdgeInsets()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == imageScrollView else { return }
        updateImageScrollEdgeInsets()
    }
    
    private func updateImageScrollEdgeInsets() {
        guard let scrollView = imageScrollView else { return }
        let offsetX = scrollView.contentOffset.x
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        
        let newState: Int
        let leftOffset: CGFloat
        let rightOffset: CGFloat
        if maxOffsetX <= 0 {
            newState = 0
            leftOffset = 20
            rightOffset = 0
        } else if offsetX <= 1 {
            newState = 0
            leftOffset = 20
            rightOffset = 0
        } else if offsetX >= maxOffsetX - 1 {
            newState = 2
            leftOffset = 0
            rightOffset = -20
        } else {
            newState = 1
            leftOffset = 0
            rightOffset = 0
        }
        guard newState != imageScrollEdgeState else { return }
        imageScrollEdgeState = newState
        imageScrollViewLeftConstraint?.update(offset: leftOffset)
        imageScrollViewRightConstraint?.update(offset: rightOffset)
        UIView.animate(withDuration: 0.15) { [weak self] in
            self?.contentView.layoutIfNeeded()
        }
    }
    
    @objc func termsButtonTapped() {
        BaseWebController.presentAsSheet(from: self, urlString: termsOfUseURL)
    }
    
    @objc func privacyButtonTapped() {
        BaseWebController.presentAsSheet(from: self, urlString: privacyPolicyURL)
    }
    
    @objc func restoreButtonTapped() {
        scanFeedbackGenerator.impactOccurred()
        scanFeedbackGenerator.prepare()
        self.restorePurchaseData()
    }
    
    @objc func handleLimitedLabelTap() {
        if isPushedOntoNavigationStack {
            navigationController?.popViewController(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        } else if let navigationController = navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    func requestSuccess() {
        weeklyProductView.set(priceString: "Then $4.99 Per Week", time: "3-Day Free Trial", rightTimeLabel: "$4.99/week")
        yearlyProductView.set(priceString: "$29.99 Per Year", time: "Yearly", rightTimeLabel: "$0.57/week")
        view.layoutNow()
    }
    
    func requestFailed() {
    }
}

extension VipUIViewController: NBInAppPurchaseProtocol {
    func subscriptionProductsDidReciveSuccess(products: [StoreProduct]) {
        weeklyProduct = products.filter({$0.productIdentifier == NBNewStoreManager.shard.weekProductId}).first
        yearlyProduct = products.filter({$0.productIdentifier == NBNewStoreManager.shard.yearProductId}).first
        requestSuccess()
    }
    
    func subscriptionProductsDidReciveFailure() {
        showAlert(content: "Unable to load subscription products. Please check your network connection and try again later.")
        requestFailed()
    }
    
    func purchasedSuccess(_ needUnsubscribe: Bool) {
        showPurchaseSuccessAlert(needUnsubscribe) { [weak self] in
            guard let self = self else { return }
            if self.isPushedOntoNavigationStack {
                self.handler?()
            } else if self.presentingViewController != nil {
                self.dismiss(animated: true, completion: self.handler)
            } else if let navigationController = self.navigationController, navigationController.viewControllers.count > 1 {
                navigationController.pushViewController(HomeViewController(), animated: false)
                self.handler?()
            } else {
                self.dismiss(animated: true, completion: self.handler)
            }
        }
    }
    
    func purchasedFailure(error: Error?) {
        let content: String
        if let error = error {
            content = "Purchase Failed: " + error.localizedDescription
        } else {
            content = "Purchase Failed"
        }
        DispatchQueue.main.async {
            self.showAlert(content: content)
        }
    }
    
    func restorePurchaseSuccess() {
        showAlert(content: "Restore Success") { [weak self] in
            guard let self = self else { return }
            if self.isPushedOntoNavigationStack {
                self.handler?()
            } else if self.presentingViewController != nil {
                self.dismiss(animated: true, completion: self.handler)
            } else if let navigationController = self.navigationController, navigationController.viewControllers.count > 1 {
                navigationController.pushViewController(HomeViewController(), animated: false)
                self.handler?()
            } else {
                self.dismiss(animated: true, completion: self.handler)
            }
        }
    }
    
    func restorePurchaseFailure() {
        showAlert(content: "Restore Failure")
    }
    
    func showPurchaseSuccessAlert(_ needUnsubscribe: Bool = false, completion: (() -> Void)? = nil) {
        showAlert(content: "Purchase Success", handler: completion)
    }
    
    func showAlert(content: String, handler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let vc = UIAlertController(title: nil, message: content, preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak vc] _ in
                vc?.dismiss(animated: true)
                handler?()
            }))
            self.present(vc, animated: true)
        }
    }
}

private enum VipSubscriptionContentGradient {
    static func configure(_ layer: CAGradientLayer) {
        layer.colors = [
            UIColor.color(hexString: "#FFE7F7").withAlphaComponent(0.25).cgColor,
            UIColor.color(hexString: "#E7E7FF").withAlphaComponent(0.25).cgColor
        ]
        layer.locations = [0.0, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }
}

private final class VipScrollContentGradientView: UIView {
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        VipSubscriptionContentGradient.configure(gradientLayer)
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
