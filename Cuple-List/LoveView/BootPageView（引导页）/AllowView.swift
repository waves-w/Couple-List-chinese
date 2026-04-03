//
//  AllowView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ReactiveSwift
import ReactiveCocoa
import SnapKit
import UserNotifications

class AllowView: UIViewController {
    
    var backButton: UIButton!
    var noticeButton: BorderGradientButton!
    var rightButton: UISwitch!
    var continueButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        loadNotificationAgreement()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadNotificationAgreement()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        BootOnboardingFlow.recordStep(.allow)
        // ✅ 进入 AllowView 页面时，只同步显示当前系统权限状态，不自动弹出权限请求
        // ✅ 权限请求只在用户点击开关按钮时才会触发
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // ✅ 根据系统权限状态同步开关显示（不自动请求权限）
                let isAuthorized = settings.authorizationStatus == .authorized
                self.rightButton.isOn = isAuthorized
                // ✅ 如果系统已授权，同步保存用户意愿
                if isAuthorized {
                    CoupleStatusManager.shared.notificationAgreed = true
                }
                print("✅ AllowView: 同步系统权限状态，状态：\(settings.authorizationStatus.rawValue)，开关状态：\(isAuthorized)")
            }
        }
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
        
        let AllowLabel = UILabel()
        AllowLabel.text = "Never miss a special moment"
        AllowLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 24)
        AllowLabel.textColor = .color(hexString: "#322D3A")
        AllowLabel.numberOfLines = 2
        AllowLabel.textAlignment = .center
        view.addSubview(AllowLabel)
        
        let xxx88 = view.height() * 88.0 / 812.0
        
        AllowLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.topMargin.equalTo(xxx88)
        }
        
        
        let EnableLabel = UILabel()
        EnableLabel.text = "Get reminders for tasks, anniversaries, and important dates."
        EnableLabel.numberOfLines = 0
        EnableLabel.textAlignment = .center
        EnableLabel.textColor = .color(hexString: "#8A8E9D")
        EnableLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        view.addSubview(EnableLabel)
        
        EnableLabel.snp.makeConstraints { make in
            make.top.equalTo(AllowLabel.snp.bottom).offset(10)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.centerX.equalToSuperview()
        }
        
        let middlePhoneImage = UIImageView(image: .middlePhone)
        view.addSubview(middlePhoneImage)
        
        let xxx20 = view.height() * 20.0 / 812.0
        middlePhoneImage.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(EnableLabel.snp.bottom).offset(xxx20)
//            make.width.equalToSuperview().multipliedBy(177.0 / 375.0)
//            make.height.equalToSuperview().multipliedBy(258.0 / 812.0)
        }
        
        noticeButton = BorderGradientButton()
        noticeButton.layer.cornerRadius = 18
        view.addSubview(noticeButton)
        
        let xxx30 = view.height() * 30.0 / 812.0
        
        noticeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(335.0 / 375.0)
            make.height.equalTo(52)
            make.top.equalTo(middlePhoneImage.snp.bottom).offset(xxx30)
        }
        
        let noticeButtonView = UIView()
        noticeButton.addSubview(noticeButtonView)
        
        noticeButtonView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let noticeButtonImage = UIImageView(image: .reminderimage)
        noticeButtonView.addSubview(noticeButtonImage)
        
        noticeButtonImage.snp.makeConstraints { make in
            make.left.equalTo(14)
            make.centerY.equalToSuperview()
        }
        
        let noticeLabel = UILabel()
        noticeLabel.text = "Notifications"
        noticeLabel.font = UIFont(name: "SFCompactRounded-Semibold", size: 15)
        noticeButtonView.addSubview(noticeLabel)
        
        noticeLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(noticeButtonImage.snp.right).offset(11)
        }
        
        rightButton = UISwitch()
        rightButton.frame = CGRect(x: 100, y: 100, width: 0, height: 0) // 设置位置
        rightButton.isOn = false // 设置初始状态为"关闭"
        rightButton.onTintColor = .systemGreen
        rightButton.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        // ✅ 注意：不在初始化时请求系统权限，只保存用户意愿
        
        // 3. 将它添加到视图层级中
        noticeButtonView.addSubview(rightButton)
        
        rightButton.snp.makeConstraints { make in
            make.right.equalTo(-14)
            make.centerY.equalToSuperview()
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
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func continueButtonTapped() {
        BootOnboardingFeedback.playContinueButton()
        self.navigationController?.pushViewController(BootPageView(), animated: true)
    }
    
    @objc func switchChanged(_ sender: UISwitch) {
        if sender.isOn {
            // ✅ 开关打开：检查系统权限，如果没有则请求
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .authorized {
                        // ✅ 已有权限，直接保存意愿
                        CoupleStatusManager.shared.notificationAgreed = true
                        print("✅ AllowView: 系统已有通知权限，用户同意发送通知")
                    } else {
                        // ✅ 没有权限，弹出系统权限请求
                        LocalNotificationManager.shared.requestNotificationPermission { granted in
                            if granted {
                                // ✅ 用户授权，保存意愿
                                CoupleStatusManager.shared.notificationAgreed = true
                                print("✅ AllowView: 用户已授权通知权限")
                            } else {
                                // ✅ 用户拒绝权限，关闭开关
                                DispatchQueue.main.async {
                                    sender.isOn = false
                                    CoupleStatusManager.shared.notificationAgreed = false
                                    
                                    // ✅ 显示提示并引导到设置
                                    let alert = UIAlertController(
                                        title: "Notification Permission Denied",
                                        message: "Please enable notification permission in Settings to receive task reminders",
                                        preferredStyle: .alert
                                    )
                                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                    alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    })
                                    self.present(alert, animated: true)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // ✅ 开关关闭：只保存用户意愿（不同意）
            CoupleStatusManager.shared.notificationAgreed = false
            print("✅ AllowView: 用户不同意发送通知")
        }
    }
    
    // ✅ 加载已保存的通知同意意愿
    private func loadNotificationAgreement() {
        let agreed = CoupleStatusManager.shared.notificationAgreed
        rightButton.isOn = agreed
        print("✅ AllowView: 加载通知同意意愿 = \(agreed)")
    }
}
