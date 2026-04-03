//
//  LinkSuccessView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class LinkSuccessView: UIViewController {
    
    var backButton: UIButton!
    var continueButton: UIButton!
    var successImageView: UIImageView!
    /// 引导流程内链接成功：Continue 进入主页并完成引导
    var isCompletingOnboardingAfterLink = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasLaunchedOnce")
        if !hasCompletedOnboarding,
           let tab = tabBarController as? MomoTabBarController {
            tab.setTabBarHidden(true)
            tab.tabBar.isUserInteractionEnabled = false
        }
//        continueButton?.setTitle((isCompletingOnboardingAfterLink && !hasCompletedOnboarding) ? "Back to Home" : "Continue", for: .normal)
    }
    
    func setUI() {
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
        
        
        // ✅ 中间的链接成功图片
        successImageView = UIImageView(image: UIImage(named: "linksuccessimage"))
        successImageView.contentMode = .scaleAspectFit
        view.addSubview(successImageView)
        
        successImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(successImageView.snp.width).multipliedBy(187.0 / 335.0)
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
    
    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc func continueButtonTapped() {
        BootOnboardingFeedback.playContinueButton()
        // ✅ 链接成功页 Continue：始终弹出订阅页，订阅成功才进入
        let enterApp = { [weak self] in
            guard let self = self else { return }
            UserDefaults.standard.set(true, forKey: "hasLaunchedOnce")
            UserDefaults.standard.synchronize()
            if self.isCompletingOnboardingAfterLink {
                BootOnboardingFlow.finishAndShowHome(from: self)
            } else {
                self.navigationController?.setViewControllers([HomeViewController()], animated: true)
            }
        }
        let vip = VipUIViewController()
        vip.handler = enterApp
        navigationController?.pushViewController(vip, animated: true)
    }
}





