//
//  WelcomeView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit

class WelcomeView: UIViewController {
    
    /// 进入首页 Tab 时要恢复的引导页；默认读 `BootOnboardingFlow.persistedStep`
    private let bootResumeStep: BootOnboardingStep
    
    init(bootResumeStep: BootOnboardingStep = BootOnboardingFlow.persistedStep) {
        self.bootResumeStep = bootResumeStep
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.bootResumeStep = BootOnboardingFlow.persistedStep
        super.init(coder: coder)
    }
    
//    var backButton: UIButton!
    var welcomeLabel: UILabel!
    var pinkloveImageView: UIImageView!
    var pinkLabel: UILabel!
    var middleImageView: UIImageView!
    var connectLabel: UILabel!
    var continueButton: UIButton!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let tabBarController = self.tabBarController as? MomoTabBarController {
            tabBarController.simulationTabBar?.isHidden = true
            if tabBarController.simulationTabBar == nil {
                tabBarController.tabBar.isHidden = true
                tabBarController.homeAddButton?.isHidden = true
            }
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 下一帧再写进度，避免与 `resumeOnboardingIfNeeded` 的异步叠栈竞态，误把已保存步骤覆盖成 welcome
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.navigationController?.topViewController === self else { return }
            BootOnboardingFlow.recordStep(.welcome)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        resumeOnboardingIfNeeded()
    }
    
    /// 未完成引导时：按引导顺序重建完整栈，回到上次所在页；返回键逐级返回，不会从中间页一跳回到 Welcome。
    private func resumeOnboardingIfNeeded() {
        guard bootResumeStep != .welcome else { return }
        let stack = BootOnboardingFlow.navigationStackThrough(through: bootResumeStep)
        guard stack.count >= 2 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.navigationController?.setViewControllers(stack, animated: false)
        }
    }
    
    func setUI() {
        view.backgroundColor = .white
        let inView = UIImageView(image: .bootbackiamge)
        view.addSubview(inView)
        inView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        pinkloveImageView = UIImageView(image: .pinklove)
        pinkloveImageView.contentMode = .scaleAspectFill
        view.addSubview(pinkloveImageView)
        
        let xxx92 = view.height() * 92.0 / 812.0
        
        pinkloveImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.topMargin.equalTo(xxx92)
            make.size.equalTo(46)
        }
    
        
        welcomeLabel = UILabel()
        welcomeLabel.text = "Welcome to Couple List"
        welcomeLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        welcomeLabel.textColor = .color(hexString: "#322D3A")
        view.addSubview(welcomeLabel)
       
        welcomeLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(pinkloveImageView.snp.bottom).offset(12)
        }
        
        connectLabel = UILabel()
        connectLabel.text = "Plan together, remember every special date, and make everyday life a little sweeter."
        connectLabel.numberOfLines = 0
        connectLabel.textAlignment = .center
        connectLabel.textColor = .color(hexString: "#8A8E9D")
        connectLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 16)
        view.addSubview(connectLabel)
        
        connectLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(welcomeLabel.snp.bottom).offset(10)
            make.left.equalTo(20)
            make.right.equalTo(-20)
        }
        
        middleImageView = UIImageView(image: .userAndlist)
        view.addSubview(middleImageView)
        
        middleImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(359.0 / 812.0)
            make.top.equalTo(connectLabel.snp.bottom).offset(12)
        }
        
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 18
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-4)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
    }
    
    //    @objc func backButtonTapped() {
    //        UserDefaults.standard.set(true, forKey: "hasLaunchedOnce")
    //            UserDefaults.standard.synchronize()
    //            if let tabBarController = self.tabBarController as? MomoTabBarController {
    //                guard let navigationController = self.navigationController else { return }
    //                let homeVc = HomeViewController()
    //                navigationController.setViewControllers([homeVc], animated: true)
    //            }
    //        }
    @objc func continueButtonTapped() {
        BootOnboardingFeedback.playContinueButton()
        BootOnboardingFlow.recordStep(.nameInput)
        self.navigationController?.pushViewController(BootNameInputViewController(), animated: true)
        
//        let vip = SaleViewController()
//        vip.modalPresentationStyle = .fullScreen
//        present(vip, animated: true)
    }
    
}
