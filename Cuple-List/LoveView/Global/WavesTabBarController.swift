//
//  WavesTabBarController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveCocoa
import ReactiveSwift
import SnapKit

class MomoTabBarController: UITabBarController {
    
    
    
    var simulationTabBar: UIView!
    var todoButton: MomoTabBarButton!
    var pointsButton: MomoTabBarButton!
    var wavesScanButton: UIButton!
    var settingButton: MomoTabBarButton!
    var anniButton: MomoTabBarButton!
    var addPopup = AddViewPopup()
    private var unlinkPopup: UnlinkConfirmPopup?
    
    var WaveshasLaunchedOnce: Bool {
        return UserDefaults.standard.bool(forKey: "hasLaunchedOnce")
    }
    
    var WavesCoupleLinked: Bool {
        return UserDefaults.standard.bool(forKey: "isCoupleLinked")
    }
    
    let scanFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    func configure() {
        tabBar.isHidden = true
        
        simulationTabBar = BorderGradientView()
        simulationTabBar.backgroundColor = .white
        view.addSubview(simulationTabBar)
        
        simulationTabBar.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(simulationTabBar.snp.width).multipliedBy(84.0 / 375.0)
        }
        
        todoButton = MomoTabBarButton(name: "To Do")
        todoButton.setSelected(true)
        todoButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.scanFeedbackGenerator.impactOccurred()
            self.scanFeedbackGenerator.prepare()
            self.todoButton.setSelected(true)
            self.pointsButton.setSelected(false)
            self.anniButton.setSelected(false)
            self.settingButton.setSelected(false)
            self.selectedIndex = 0
        }
        simulationTabBar.addSubview(todoButton)
        
        todoButton.snp.makeConstraints { make in
            make.left.equalTo(24)
            make.width.equalToSuperview().multipliedBy(40.0 / 375.0)
            make.height.equalTo(60)
            make.top.equalTo(10)
        }
        
        pointsButton = MomoTabBarButton(name: "Points")
        pointsButton.setSelected(false)
        pointsButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.scanFeedbackGenerator.impactOccurred()
            self.scanFeedbackGenerator.prepare()
            self.todoButton.setSelected(false)
            self.pointsButton.setSelected(true)
            self.anniButton.setSelected(false)
            self.settingButton.setSelected(false)
            self.selectedIndex = 1
        }
        simulationTabBar.addSubview(pointsButton)
        
        pointsButton.snp.makeConstraints { make in
            make.left.equalTo(todoButton.snp.right).offset(29)
            make.width.equalToSuperview().multipliedBy(40.0 / 375.0)
            make.height.equalTo(60)
            make.top.equalTo(10)
        }
        
        wavesScanButton = UIButton()
        wavesScanButton.setImage(UIImage(named: "homeAddButton"), for: .normal)
        wavesScanButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.scanFeedbackGenerator.impactOccurred()
            self.scanFeedbackGenerator.prepare()
            self.showaddPopup()
        }
        simulationTabBar.addSubview(wavesScanButton)
        
        wavesScanButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(10)
        }
        
        settingButton = MomoTabBarButton(name:"Setting")
        settingButton.setSelected(false)
        settingButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.scanFeedbackGenerator.impactOccurred()
            self.scanFeedbackGenerator.prepare()
            self.todoButton.setSelected(false)
            self.pointsButton.setSelected(false)
            self.anniButton.setSelected(false)
            self.settingButton.setSelected(true)
            self.selectedIndex = 3
        }
        simulationTabBar.addSubview(settingButton)
        
        settingButton.snp.makeConstraints { make in
            make.right.equalTo(-24)
            make.width.equalToSuperview().multipliedBy(40.0 / 375.0)
            make.height.equalTo(60)
            make.top.equalTo(10)
        }
        
        anniButton = MomoTabBarButton(name:"Anni")
        anniButton.setSelected(false)
        anniButton.reactive.controlEvents(.touchUpInside).observeValues {
            [weak self] _ in
            guard let self = self else { return }
            self.scanFeedbackGenerator.impactOccurred()
            self.scanFeedbackGenerator.prepare()
            self.todoButton.setSelected(false)
            self.pointsButton.setSelected(false)
            self.anniButton.setSelected(true)
            self.settingButton.setSelected(false)
            self.selectedIndex = 2
        }
        simulationTabBar.addSubview(anniButton)
        
        anniButton.snp.makeConstraints { make in
            make.right.equalTo(settingButton.snp.left).offset(-29)
            make.width.equalToSuperview().multipliedBy(40.0 / 375.0)
            make.height.equalTo(60)
            make.top.equalTo(10)
        }
        
        
        
        func navigationVC(rootVC: UIViewController) -> UINavigationController {
            let navigationController = UINavigationController(rootViewController: rootVC)
            navigationController.interactivePopGestureRecognizer?.delegate = nil
            navigationController.setNavigationBarHidden(true, animated: false)
            return navigationController
        }
        viewControllers = [
            navigationVC(rootVC: WaveshasLaunchedOnce ? HomeViewController() : WelcomeView(bootResumeStep: BootOnboardingFlow.persistedStep)),
            navigationVC(rootVC: PointsView()),
            navigationVC(rootVC: AnniViewController()),
            navigationVC(rootVC: SettingViewController())
        ]
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
        
        var homeVC: HomeViewController?
        if let tabBarController = self as? UITabBarController {
            for vc in tabBarController.viewControllers ?? [] {
                guard let nav = vc as? UINavigationController else { continue }
                for child in nav.viewControllers {
                    if let home = child as? HomeViewController {
                        homeVC = home
                        break
                    }
                }
                if homeVC != nil { break }
            }
            if homeVC == nil, #available(iOS 26, *), !tabBarController.tabs.isEmpty {
                let firstTabVC = tabBarController.tabs[0].viewController
                if let nav = firstTabVC as? UINavigationController {
                    for child in nav.viewControllers {
                        if let home = child as? HomeViewController {
                            homeVC = home
                            break
                        }
                    }
                }
            }
        }
        addPopup.homeViewController = homeVC
        if homeVC == nil {
            print("Warning: HomeViewController not found or structure changed for AddViewPopup context.")
        }
        // 先让当前界面失焦收键盘，再弹窗，减轻第三方键盘在弹窗内的卡顿
        view.endEditing(true)
        let safeAreaBottom = view.window?.safeAreaInsets.bottom ?? 34.0
        addPopup.show(width: view.width(), bottomSpacing: safeAreaBottom)
    }
    
    
    class MomoTabBarButton: UIButton {
        var topLine: UIView!
        var iconImageView: UIImageView!
        var nameLabel: UILabel!
        var name = ""
        
        var checked = false
        
        convenience init(name: String) {
            self.init()
            self.name = name
            configure()
        }
        
        func configure() {
            
            iconImageView = UIImageView()
            addSubview(iconImageView)
            
            iconImageView.snp.makeConstraints { make in
                make.centerY.equalToSuperview().offset(-10)
                make.centerX.equalToSuperview()
                
            }
            
            nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 11)
            addSubview(nameLabel)
            
            nameLabel.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.bottom.equalTo(-12)
            }
        }
        
        func setSelected(_ selected: Bool ,animated: Bool = true) {
            self.checked = selected
            iconImageView.image = UIImage(named: "TabBar_\(name)_" + (selected ? "Selected" : "Unselected"))
            let selectedColorHex = "#322D3A"
            let unselectedColorHex = "#C0C0C0"
            nameLabel.textColor = UIColor.color(hexString: selected ? selectedColorHex : unselectedColorHex)
        }
    }
}
