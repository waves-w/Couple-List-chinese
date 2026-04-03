//
//  LinkLoadingView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import Lottie

class LinkLoadingView: UIViewController {
    
    private let partnerCode: String
    private let kIsCoupleLinked = "isCoupleLinked"
    
    /// Lottie 动画文件名（不含 .json），放在项目里并加入 Target 的 Copy Bundle Resources
    private let kLottieAnimationName = "链接动画"
    
    private var activityIndicator: UIActivityIndicatorView!
    private var lottieAnimationView: LottieAnimationView?
    private var statusLabel: UILabel!
    private var failedImageView: UIImageView!
    private var failedTitleLabel: UILabel!
    private var errorLabel: UILabel!
    private var continueButton: UIButton!
    private var backButton: UIButton!
    
    init(partnerCode: String) {
        self.partnerCode = partnerCode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startLink()
    }
    
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
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
        }
        
        // 优先使用 Lottie JSON 动画，若无则使用系统 UIActivityIndicatorView
        if let animation = loadLottieAnimation(named: kLottieAnimationName) {
            lottieAnimationView = LottieAnimationView(animation: animation)
            lottieAnimationView?.loopMode = .loop
            lottieAnimationView?.contentMode = .scaleAspectFit
            lottieAnimationView?.backgroundBehavior = .pauseAndRestore
            if let lottie = lottieAnimationView {
                view.addSubview(lottie)
                lottie.snp.makeConstraints { make in
                    make.centerX.equalToSuperview()
                    make.centerY.equalToSuperview().offset(-65)
                }
            }
        }
        //系统加载
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .gray
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-50)
        }
        
        statusLabel = UILabel()
        statusLabel.text = "Waiting for your partner to connect…"
        statusLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)
        statusLabel.textColor = .color(hexString: "#322D3A")
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints { make in
            make.left.equalTo(32)
            make.right.equalTo(-32)
            make.top.equalTo(activityIndicator.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }
        
        // 链接失败时：图片 + 标题 + 文案
        failedImageView = UIImageView(image: UIImage(named: "linkfailed"))
        failedImageView.contentMode = .scaleAspectFit
        failedImageView.isHidden = true
        view.addSubview(failedImageView)
        failedImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-65)
//            make.width.lessThanOrEqualTo(200)
//            make.height.lessThanOrEqualTo(200)
        }
        
        failedTitleLabel = UILabel()
        failedTitleLabel.text = "Connection failed"
        failedTitleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 20)
        failedTitleLabel.textColor = .color(hexString: "#322D3A")
        failedTitleLabel.textAlignment = .center
        failedTitleLabel.isHidden = true
        view.addSubview(failedTitleLabel)
        failedTitleLabel.snp.makeConstraints { make in
            make.left.equalTo(32)
            make.right.equalTo(-32)
            make.top.equalTo(failedImageView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }
        
        errorLabel = UILabel()
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        errorLabel.textColor = .color(hexString: "#8A8E9D")
        errorLabel.isHidden = true
        view.addSubview(errorLabel)
        errorLabel.snp.makeConstraints { make in
            make.left.equalTo(40)
            make.right.equalTo(-40)
            make.top.equalTo(failedTitleLabel.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
        }
        
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.backgroundColor = .color(hexString: "#111111")
        continueButton.layer.cornerRadius = 22
        continueButton.setTitleColor(.color(hexString: "#FFFFFF"), for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Heavy", size: 16)
        continueButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        continueButton.isHidden = true
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.height.equalTo(52)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(327.0 / 375.0)
        }
    }
    
    /// 从 Bundle 加载 Lottie 动画（Animations 子目录下的 name.json 或根目录）
    private func loadLottieAnimation(named name: String) -> LottieAnimation? {
        // 先尝试带子目录的路径（Xcode 会保留 Animations 目录结构）
        if let anim = try? LottieAnimation.named("Animations/\(name)") { return anim }
        return try? LottieAnimation.named(name)
    }
    
    @objc private func backTapped() {
        BootOnboardingFeedback.playContinueButton()
        navigationController?.popViewController(animated: true)
    }
    
    private func appendLog(_ message: String) {
        print("🔗 [Firebase链接] \(message)")
    }
    
    private func startLink() {
        appendLog("========== 主动链接流程开始 ==========")
        appendLog("步骤0: 初始化 UI，准备发起链接")
        
        if lottieAnimationView != nil {
            lottieAnimationView?.isHidden = false
            lottieAnimationView?.play()
            activityIndicator.stopAnimating()
        } else {
            activityIndicator.startAnimating()
        }
        statusLabel.isHidden = false
        failedImageView.isHidden = true
        failedTitleLabel.isHidden = true
        errorLabel.isHidden = true
        continueButton.isHidden = true
        
        guard let ownCode = CoupleStatusManager.shared.ownInvitationCode, ownCode.count == 8 else {
            appendLog("❌ 步骤0失败: 自己的邀请码未就绪")
            showError("Your ID is not ready yet. Please try again.")
            return
        }
        appendLog("步骤1: 邀请码就绪 own=\(ownCode) partner=\(partnerCode)")
        
        let db = Firestore.firestore()
        appendLog("步骤2: 读取 pending_invitations/\(partnerCode)...")
        db.collection("pending_invitations").document(partnerCode).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.appendLog("❌ 步骤2失败: \(error.localizedDescription)")
                    self.showError("Link failed: \(error.localizedDescription)")
                    return
                }
                guard let document = document, document.exists else {
                    self.appendLog("❌ 步骤2失败: pending_invitations 文档不存在")
                    self.showError("Invite code not found. Please check the code and try again.")
                    return
                }
                let partnerUUID = document.data()?["userUUID"] as? String ?? ""
                guard !partnerUUID.isEmpty else {
                    self.appendLog("❌ 步骤2失败: 文档中无 userUUID")
                    self.showError("Partner UUID not found in invitation.")
                    return
                }
                self.appendLog("步骤2完成: 已读取对方 UUID")
                
                let isInitiator = true
                let linkData: [String: Any] = [
                    "partnerId": ownCode,
                    "initiatorUUID": CoupleStatusManager.getUserUniqueUUID(),
                    "linkTime": FieldValue.serverTimestamp()
                ]
                
                self.appendLog("步骤3: 写入 linked_couples/\(self.partnerCode)...")
                db.collection("linked_couples").document(self.partnerCode).setData(linkData) { [weak self] linkError in
                    guard let self = self else { return }
                    if let linkError = linkError {
                        self.appendLog("❌ 步骤3失败: \(linkError.localizedDescription)")
                        DispatchQueue.main.async {
                            self.showError("Link failed: \(linkError.localizedDescription)")
                        }
                        return
                    }
                    self.appendLog("步骤3完成: linked_couples 写入成功")
                    
                    self.appendLog("步骤4: 本地 setLinked + syncMyLinkStateToFirebase")
                    CoupleStatusManager.shared.setLinked(partnerId: self.partnerCode, isInitiator: isInitiator)
                    UserDefaults.standard.set(true, forKey: self.kIsCoupleLinked)
                    UserManger.manager.syncMyLinkStateToFirebase()
                    
                    self.appendLog("步骤5: syncCoupleUserInfoAfterLink...")
                    UserManger.manager.syncCoupleUserInfoAfterLink(partner8DigitId: self.partnerCode) { success in
                        if success {
                            self.appendLog("步骤5完成: 用户信息同步成功")
                        } else {
                            self.appendLog("⚠️ 步骤5: 用户信息同步失败，继续跳转")
                        }
                        self.appendLog("步骤6: 跳转 LinkSuccessView")
                        NotificationCenter.default.post(name: NSNotification.Name("CoupleDidLinkNotification"), object: nil)
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            guard self.isViewLoaded && self.view.window != nil else { return }
                            self.navigateToLinkSuccess()
                            self.appendLog("========== 主动链接流程结束 ==========")
                        }
                    }
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        lottieAnimationView?.stop()
        lottieAnimationView?.isHidden = true
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
        failedImageView.isHidden = false
        failedTitleLabel.isHidden = false
        errorLabel.text = message
        errorLabel.isHidden = false
        continueButton.isHidden = false
    }
    
    private func navigateToLinkSuccess() {
        guard let nav = navigationController else { return }
        let success = LinkSuccessView()
        success.isCompletingOnboardingAfterLink = true
        var vcs = nav.viewControllers
        if let idx = vcs.firstIndex(where: { $0 is LinkLoadingView }) {
            vcs[idx] = success
            nav.setViewControllers(vcs, animated: true)
        } else {
            nav.pushViewController(success, animated: true)
        }
    }
}
