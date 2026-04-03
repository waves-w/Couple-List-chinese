//
//  MomoTabBarController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveCocoa
import ReactiveSwift
import SnapKit

// MARK: - 添加按钮回调（iOS 26 的添加 tab / 非 iOS 26 的 homeAddButton 点击时通过此代理通知）
protocol MomoTabBarControllerAddDelegate: AnyObject {
    func momoTabBarControllerDidTapAdd(_ controller: MomoTabBarController)
}

/// 第 4 个“添加”tab 的占位 VC；若 shouldSelect 未被系统调用，在 viewWillAppear 立即弹窗并切回首页
private class AddPlaceholderViewController: UIViewController {
    var onWillAppear: (() -> Void)?
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onWillAppear?()
    }
}

class MomoTabBarController: UITabBarController {
    
    weak var addDelegate: MomoTabBarControllerAddDelegate?
    
    /// iOS 26 时为 nil（使用系统 tabBar）；非 iOS 26 为自定义底部栏
    var simulationTabBar: UIView?
    var tabItemsContainerView: UIView?
    var todoButton: MomoTabBarButton?
    var homeAddButton: UIButton?
    var settingButton: MomoTabBarButton?
    var anniButton: MomoTabBarButton?
    var addPopup = AddViewPopup()
    private var unlinkPopup: UnlinkConfirmPopup?
    /// iOS 26 时第 4 个（添加）tab 的占位 VC，强引用以便在 shouldSelect 里用 === 识别
    private var addPlaceholderVC: AddPlaceholderViewController?
    /// iOS 26 前三个 tab 的标题，用于 didSelect 时切换 Selected/Unselected 图标
    private let tabBarItemNames = ["To Do", "Moments", "Settings"]
    
    /// 统一隐藏/显示底部栏；仅改 isHidden，不改 isUserInteractionEnabled，避免返回后整页点不了
    func setTabBarHidden(_ hidden: Bool) {
        simulationTabBar?.isHidden = hidden
        if simulationTabBar == nil {
            tabBar.isHidden = hidden
            homeAddButton?.isHidden = hidden
        }
    }
    
    /// 底部栏占用的高度（用于详情页 additionalSafeAreaInsets）；从 Home 关掉 Add 弹窗后 push 详情时先 layoutIfNeeded 再取
    func tabBarAreaHeight() -> CGFloat {
        if let sim = simulationTabBar {
            let h = sim.bounds.height > 0 ? sim.bounds.height : 62
            return max(h, 62)
        }
        let barH = tabBar.frame.height > 0 ? tabBar.frame.height : 49
        return max(barH, 49)
    }
    
    /// 从 view 底部到 tabBar 顶边的距离（用于 Home/Anni 的 tableView 底部与 tabBar 顶对齐）
    func tabBarTopInsetFromBottom() -> CGFloat {
        if simulationTabBar != nil {
            return 34 + tabBarAreaHeight()
        }
        return tabBarAreaHeight()
    }
    
    var WaveshasLaunchedOnce: Bool {
        return UserDefaults.standard.bool(forKey: "hasLaunchedOnce")
    }
    
    var WavesCoupleLinked: Bool {
        return UserDefaults.standard.bool(forKey: "isCoupleLinked")
    }
    
    let scanFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    /// 已完成引导且未订阅时，冷启动仅在首次进入主 Tab 时弹出一次订阅页
    private var didPresentLaunchPaywallForNonSubscriber = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addDelegate = self
        configure()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 26, *), let items = tabBar.items, items.count >= 3 {
            let orig = { (name: String) in UIImage(named: name)?.withRenderingMode(.alwaysOriginal) }
            for i in 0..<3 {
                items[i].image = orig("TabBar_\(tabBarItemNames[i])_Unselected")
                items[i].selectedImage = orig("TabBar_\(tabBarItemNames[i])_Selected")
            }
        }
        presentLaunchPaywallIfNeededAfterOnboarding()
    }
    
    private func presentLaunchPaywallIfNeededAfterOnboarding() {
        guard WaveshasLaunchedOnce else { return }
        guard !SubscriptionPaywallGate.isSubscriptionActive else { return }
        guard !didPresentLaunchPaywallForNonSubscriber else { return }
        guard presentedViewController == nil else { return }
        didPresentLaunchPaywallForNonSubscriber = true
        SubscriptionPaywallGate.presentPaywall(from: self)
    }
    
    func configure() {
        self.delegate = self
        
        func navigationVC(rootVC: UIViewController) -> UINavigationController {
            let navigationController = UINavigationController(rootViewController: rootVC)
            navigationController.interactivePopGestureRecognizer?.delegate = nil
            navigationController.setNavigationBarHidden(true, animated: false)
            return navigationController
        }
        let homeNav = navigationVC(rootVC: WaveshasLaunchedOnce ? HomeViewController() : WelcomeView(bootResumeStep: BootOnboardingFlow.persistedStep))
        let anniNav = navigationVC(rootVC: AnniViewController())
        let settingNav = navigationVC(rootVC: SettingViewController())
        
        if #available(iOS 26, *) {
            tabBar.isHidden = false
            tabBar.isUserInteractionEnabled = true
            // 选中 #9771FF，未选中 #322D3A，标题不加粗
            let selectedColor = UIColor.color(hexString: "#9771FF")
            let unselectedColor = UIColor.color(hexString: "#322D3A")
            tabBar.tintColor = selectedColor
            tabBar.unselectedItemTintColor = unselectedColor
            let titleFont = UIFont(name: "SFCompactRounded-Semibold", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .regular)
            let appearance = UITabBarAppearance()
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: selectedColor,
                .font: titleFont
            ]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: unselectedColor,
                .font: titleFont
            ]
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
            let orig = { (name: String) in UIImage(named: name)?.withRenderingMode(.alwaysOriginal) }
            // 直接给 nav 设置 tabBarItem.image / selectedImage，系统会按选中态切换
            homeNav.tabBarItem.image = orig("TabBar_\(tabBarItemNames[0])_Unselected")
            homeNav.tabBarItem.selectedImage = orig("TabBar_\(tabBarItemNames[0])_Selected")
            homeNav.tabBarItem.title = tabBarItemNames[0]
            anniNav.tabBarItem.image = orig("TabBar_\(tabBarItemNames[1])_Unselected")
            anniNav.tabBarItem.selectedImage = orig("TabBar_\(tabBarItemNames[1])_Selected")
            anniNav.tabBarItem.title = tabBarItemNames[1]
            settingNav.tabBarItem.image = orig("TabBar_\(tabBarItemNames[2])_Unselected")
            settingNav.tabBarItem.selectedImage = orig("TabBar_\(tabBarItemNames[2])_Selected")
            settingNav.tabBarItem.title = tabBarItemNames[2]
            let homeTab = UITab(title: tabBarItemNames[0], image: orig("TabBar_\(tabBarItemNames[0])_Unselected"), identifier: "todo") { _ in homeNav }
            let anniTab = UITab(title: tabBarItemNames[1], image: orig("TabBar_\(tabBarItemNames[1])_Unselected"), identifier: "anni") { _ in anniNav }
            let settingTab = UITab(title: tabBarItemNames[2], image: orig("TabBar_\(tabBarItemNames[2])_Unselected"), identifier: "setting") { _ in settingNav }
            let addPlaceholder = AddPlaceholderViewController()
            addPlaceholder.onWillAppear = { [weak self] in
                guard let self = self, self.tabs.count >= 4 else { return }
                self.scanFeedbackGenerator.impactOccurred()
                self.scanFeedbackGenerator.prepare()
                self.addDelegate?.momoTabBarControllerDidTapAdd(self)
                self.selectedTab = self.tabs[0]
            }
            addPlaceholderVC = addPlaceholder
            let addTab = UISearchTab { _ in addPlaceholder }
            addTab.image = UIImage(named: "glassbutton")?.withRenderingMode(.alwaysOriginal)
            addTab.title = ""
            tabs = [homeTab, anniTab, settingTab, addTab]
            selectedTab = homeTab
            delegate = self
            simulationTabBar = nil
            tabItemsContainerView = nil
            todoButton = nil
            anniButton = nil
            settingButton = nil
            homeAddButton = nil
        } else {
            tabBar.isHidden = true
            viewControllers = [homeNav, anniNav, settingNav]
            selectedIndex = 0
            
            let bar = UIView()
            bar.backgroundColor = .clear
            view.addSubview(bar)
            bar.snp.makeConstraints { make in
                make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
                make.bottom.equalToSuperview().offset(-34)
                make.height.equalTo(bar.snp.width).multipliedBy(62.0 / 335.0)
                make.centerX.equalToSuperview()
            }
            simulationTabBar = bar
            
            let container = UIView()
            container.backgroundColor = .white
            container.layer.cornerRadius = 31
            container.clipsToBounds = true
            bar.addSubview(container)
            container.snp.makeConstraints { make in
                make.left.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(263.0 / 335.0)
                make.centerY.equalToSuperview()
                make.height.equalTo(bar.snp.width).multipliedBy(62.0 / 335.0)
            }
            tabItemsContainerView = container
            
            let blurView = UIVisualEffectView(effect: nil)
            blurView.layer.cornerRadius = 24
            blurView.clipsToBounds = true
            blurView.backgroundColor = .white
            container.addSubview(blurView)
            blurView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
//            let homeAddButtonSize: CGFloat = 62
            let addBtn = UIButton()
            addBtn.setImage(UIImage(named: "homeAddButton"), for: .normal)
            addBtn.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                guard let self = self else { return }
                self.scanFeedbackGenerator.impactOccurred()
                self.scanFeedbackGenerator.prepare()
                self.addDelegate?.momoTabBarControllerDidTapAdd(self)
            }
            bar.addSubview(addBtn)
            addBtn.snp.makeConstraints { make in
                make.right.equalToSuperview()
//                make.left.equalTo(container.snp.right).offset(10)
                make.centerY.equalTo(container)
                make.height.equalToSuperview()
                make.width.equalTo(container.snp.height)
            }
            homeAddButton = addBtn
            
            let todo = MomoTabBarButton(name: "To Do")
            todo.setSelected(true)
            todo.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                guard let self = self else { return }
                self.scanFeedbackGenerator.impactOccurred()
                self.scanFeedbackGenerator.prepare()
                self.todoButton?.setSelected(true)
                self.anniButton?.setSelected(false)
                self.settingButton?.setSelected(false)
                self.selectedIndex = 0
            }
            container.addSubview(todo)
            todo.snp.makeConstraints { make in
                make.left.top.bottom.equalToSuperview()
                make.width.equalTo(container.snp.width).dividedBy(3)
            }
            todoButton = todo
            
            let setting = MomoTabBarButton(name: "Settings")
            setting.setSelected(false)
            setting.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                guard let self = self else { return }
                self.scanFeedbackGenerator.impactOccurred()
                self.scanFeedbackGenerator.prepare()
                self.todoButton?.setSelected(false)
                self.anniButton?.setSelected(false)
                self.settingButton?.setSelected(true)
                self.selectedIndex = 2
            }
            container.addSubview(setting)
            setting.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.left.equalTo(todo.snp.right)
                make.width.equalTo(container.snp.width).dividedBy(3)
            }
            settingButton = setting
            
            let anni = MomoTabBarButton(name: "Moments")
            anni.setSelected(false)
            anni.reactive.controlEvents(.touchUpInside).observeValues { [weak self] _ in
                guard let self = self else { return }
                self.scanFeedbackGenerator.impactOccurred()
                self.scanFeedbackGenerator.prepare()
                self.todoButton?.setSelected(false)
                self.anniButton?.setSelected(true)
                self.settingButton?.setSelected(false)
                self.selectedIndex = 1
            }
            container.addSubview(anni)
            anni.snp.makeConstraints { make in
                make.right.top.bottom.equalToSuperview()
                make.left.equalTo(setting.snp.right)
            }
            anniButton = anni
        }
    }
    
    @objc func showaddPopup() {
        // ✅ 未链接或已断开链接：点击 add 按钮显示“去链接”弹窗（DEBUG/Release 一致）
        let isLinked = CoupleStatusManager.shared.isUserLinked && CoupleStatusManager.getPartnerId() != nil
        guard isLinked else {
            CoupleStatusManager.shared.resetAllStatus()
            unlinkPopup = UnlinkConfirmPopup(
                title: "No partner added",
                message: "Connect with a partner to create and assign \ntasks.",
                imageName: "unlinkpopimage",
                cancelTitle: "Cancel",
                confirmTitle: "Link Companion",
                confirmBlock: { [weak self] in
                    guard let self = self else { return }
                    self.unlinkPopup = nil
                    let cheekVc = CheekBootPageView()
                    cheekVc.modalPresentationStyle = .fullScreen
                    cheekVc.isPresentedFromUnlink = true
                    let nav = UINavigationController(rootViewController: cheekVc)
                    nav.modalPresentationStyle = .fullScreen
                    nav.setNavigationBarHidden(true, animated: false)
                    self.present(nav, animated: true)
                },
                cancelBlock: { [weak self] in
                    self?.unlinkPopup = nil
                }
            )
            unlinkPopup?.show()
            return
        }
        
        guard SubscriptionPaywallGate.requireSubscription(from: self) else { return }
        
//        var homeVC: HomeViewController?
//        if let tabBarController = self as? UITabBarController {
//            for vc in tabBarController.viewControllers ?? [] {
//                guard let nav = vc as? UINavigationController else { continue }
//                for child in nav.viewControllers {
//                    if let home = child as? HomeViewController {
//                        homeVC = home
//                        break
//                    }
//                }
//                if homeVC != nil { break }
//            }
//            if homeVC == nil, #available(iOS 26, *), !tabBarController.tabs.isEmpty {
//                let firstTabVC = tabBarController.tabs[0].viewController
//                if let nav = firstTabVC as? UINavigationController {
//                    for child in nav.viewControllers {
//                        if let home = child as? HomeViewController {
//                            homeVC = home
//                            break
//                        }
//                    }
//                }
//            }
//        }
//        addPopup.homeViewController = homeVC
//        if homeVC == nil {
//            print("Warning: HomeViewController not found or structure changed for AddViewPopup context.")
//        }
        // 先让当前界面失焦收键盘，再弹窗，减轻第三方键盘在弹窗内的卡顿
        view.endEditing(true)
        let safeAreaBottom = view.window?.safeAreaInsets.bottom ?? 34.0
        addPopup.show(width: view.width(), bottomSpacing: safeAreaBottom)
    }
    
    
    class MomoTabBarButton: UIButton {
        var iconImageView: UIImageView!
        var nameLabel: UILabel!
        var name = ""
        var checked = false
        /// 选中时按钮下方的背景（仅非 iOS 26 的自定义 tabBar 使用）
        private var selectedBackgroundView: UIView?
        
        convenience init(name: String) {
            self.init()
            self.name = name
            configure()
        }
        
        func configure() {
            let bg = UIView()
            bg.backgroundColor = UIColor.color(hexString: "#F8F8F8")
            bg.layer.cornerRadius = 25
            bg.isHidden = true
            bg.isUserInteractionEnabled = false
            insertSubview(bg, at: 0)
            bg.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(6)
            }
            selectedBackgroundView = bg
            
            iconImageView = UIImageView()
            iconImageView.contentMode = .scaleAspectFit
            addSubview(iconImageView)
            iconImageView.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview().offset(-8)
            }
            
            nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 11)
            addSubview(nameLabel)
            nameLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalTo(iconImageView.snp.bottom).offset(4)
            }
        }
        
        func setSelected(_ selected: Bool, animated: Bool = true) {
            checked = selected
            selectedBackgroundView?.isHidden = !selected
            iconImageView.image = UIImage(named: "TabBar_\(name)_" + (selected ? "Selected" : "Unselected"))
            let selectedColorHex = "#322D3A"
            let unselectedColorHex = "#C0C0C0"
            nameLabel.textColor = UIColor.color(hexString: selected ? selectedColorHex : unselectedColorHex)
        }
    }
}

// MARK: - UITabBarControllerDelegate（拦截添加 tab + 切换时更新前三个 tab 的 Selected/Unselected 图标）
extension MomoTabBarController: UITabBarControllerDelegate {
//    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
//        guard #available(iOS 26, *) else { return true }
//        var isAddTab = viewController is AddPlaceholderViewController
//            || (addPlaceholderVC != nil && viewController === addPlaceholderVC)
//            || (tabBarController.tabs.count > 3 && tabBarController.tabs[3].viewController === viewController)
//        if !isAddTab, let vcs = tabBarController.viewControllers, vcs.count > 3, vcs[3] === viewController {
//            isAddTab = true
//        }
//        if isAddTab {
//            scanFeedbackGenerator.impactOccurred()
//            scanFeedbackGenerator.prepare()
//            addDelegate?.momoTabBarControllerDidTapAdd(self)
//            return false
//        }
    //
//        return true
//    }
    
    
//    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
//        scanFeedbackGenerator.impactOccurred()
//        scanFeedbackGenerator.prepare()
//    }
    
    
    @available(iOS 18.0, *)
    func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        if tab is UISearchTab {
            scanFeedbackGenerator.impactOccurred()
            scanFeedbackGenerator.prepare()
            self.addDelegate?.momoTabBarControllerDidTapAdd(self)
            return false
        }
        return true
    }
    
    
    @available(iOS 18.0, *)
    func tabBarController(_ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?) {
        scanFeedbackGenerator.impactOccurred()
        scanFeedbackGenerator.prepare()
    }
}

// MARK: - MomoTabBarControllerAddDelegate（默认由自己实现：点击添加按钮时弹出原有添加弹窗）
extension MomoTabBarController: MomoTabBarControllerAddDelegate {
    func momoTabBarControllerDidTapAdd(_ controller: MomoTabBarController) {
        showaddPopup()
    }
}

