//
//  SaleViewController.swift
//  Cuple-List
//
//  Created by wanghaojun.
//

import UIKit
import SnapKit

class SaleViewController: UIViewController {
    
    var backButton: UIButton!
    var continueButton: UIButton!
    var privacyButton: UIButton!
    var termsButton: UIButton!
    
    private var bottomContainer: UIView!
    
    /// Continue 按钮点击后执行，默认 push 到订阅页
    var onContinueTapped: (() -> Void)?
    
    private let privacyPolicyURL = "https://stonehunter.privacy-policy.omis.app"
    private let termsOfUseURL = "https://stonehunter.terms-of-use.omis.app"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    func configure() {
        view.backgroundColor = .white
        
        // 背景：saleView
        let saleBackgroundView = UIImageView(image: UIImage(named: "saleView"))
        saleBackgroundView.contentMode = .scaleAspectFill
        saleBackgroundView.clipsToBounds = true
        view.addSubview(saleBackgroundView)
        saleBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 底部容器（与订阅页一致）
        bottomContainer = UIView()
        bottomContainer.backgroundColor = .clear
        view.addSubview(bottomContainer)
        bottomContainer.snp.makeConstraints { make in
            make.height.equalToSuperview().multipliedBy(140.0 / 812.0)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(-bottomSpacing())
        }
        
        let bottomBackImage = UIImageView(image: UIImage(named: "bottomback"))
        bottomContainer.addSubview(bottomBackImage)
        bottomBackImage.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Continue 上方的文本（与订阅页一致）
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
        
        // Continue 按钮（与订阅页一致）
        continueButton = UIButton()
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 18
        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        bottomContainer.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.left.equalTo(24)
            make.right.equalTo(-24)
            make.height.equalTo(52)
            make.top.equalTo(agreeLabel.snp.bottom).offset(12)
        }
        continueButton.clipsToBounds = true
        
        // Terms of Use + Privacy Policy 按钮（与订阅页一致，两个按钮 + 竖线）
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
            make.top.equalTo(continueButton.snp.bottom).offset(4)
        }
        
        // 竖线（与订阅页一致）
        let separatorLine = UIView()
        separatorLine.backgroundColor = .color(hexString: "#8A8E9D")
        bottomContainer.addSubview(separatorLine)
        separatorLine.snp.makeConstraints { make in
            make.width.equalTo(1)
            make.height.equalTo(12)
            make.centerX.equalToSuperview()
            make.centerY.equalTo(linksStack)
        }
        
        // 顶部：Back + Continue
        backButton = UIButton()
        backButton.setImage(UIImage(named: "listback"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalTo(24)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
        }
        
        let saleImage = UIImageView(image: .saleimage)
        view.addSubview(saleImage)
        let xxx24 = view.height() * 16.0 / 812.0
        saleImage.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(backButton.snp.bottom).offset(xxx24)
        }
        
        let limitedLabel = UILabel()
        limitedLabel.text = "Limited-time offer"
        limitedLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)
        limitedLabel.textColor = .color(hexString: "#000000")
        view.addSubview(limitedLabel)
       
        limitedLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(saleImage.snp.bottom).offset(-12)
        }
        
        let fiveLabel = UILabel()
        
    }
    
    @objc private func backButtonTapped() {
        if let navigationController = navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
    
    @objc private func continueButtonTapped() {
        if let handler = onContinueTapped {
            handler()
        } else {
            // 默认跳转到订阅页
            let vipVC = VipUIViewController()
            vipVC.handler = { [weak self] in
                if let nav = self?.navigationController, nav.viewControllers.count > 1 {
                    nav.pushViewController(HomeViewController(), animated: false)
                } else {
                    self?.dismiss(animated: true)
                }
            }
            if let nav = navigationController {
                nav.pushViewController(vipVC, animated: true)
            } else {
                let nav = UINavigationController(rootViewController: vipVC)
                nav.modalPresentationStyle = .fullScreen
                present(nav, animated: true)
            }
        }
    }
    
    @objc private func termsButtonTapped() {
        BaseWebController.presentAsSheet(from: self, urlString: termsOfUseURL)
    }
    
    @objc private func privacyButtonTapped() {
        BaseWebController.presentAsSheet(from: self, urlString: privacyPolicyURL)
    }
}
