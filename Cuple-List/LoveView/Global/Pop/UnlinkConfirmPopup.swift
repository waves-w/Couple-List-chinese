//
//  UnlinkConfirmPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class UnlinkConfirmPopup: NSObject, UIGestureRecognizerDelegate {
    /// 遮罩 tag，用于链接成功后强制移除可能残留的弹窗（避免卡死）
    static let kUnlinkConfirmMaskTag = 0x8E7F3A01
    
    typealias ConfirmBlock = () -> Void
    typealias CancelBlock = () -> Void
    
    private var confirmBlock: ConfirmBlock?
    private var cancelBlock: CancelBlock?
    
    private let maskView = UIView()
    private let alertContainer = UIView()
    
    // 自定义配置参数（外部可传，默认有默认值）
    private var title: String
    private var message: String
    private var imageName: String?
    private var cancelTitle: String
    private var confirmTitle: String
    /// 弹窗高度占屏高比例，断开确认文案较长时用更大值避免裁切
    private var containerHeightRatio: CGFloat
    
    // MARK: - 初始化（支持自定义参数）
    init(title: String = "No partner added",
         message: String = "Connect with a partner to create and assign \ntasks.",
         imageName: String? = "unlinkpopimage",
         cancelTitle: String = "Cancel",
         confirmTitle: String = "Link Companion",
         containerHeightRatio: CGFloat = 296.0 / 812.0,
         confirmBlock: @escaping ConfirmBlock,
         cancelBlock: CancelBlock? = nil) {
        
        self.title = title
        self.message = message
        self.imageName = imageName
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.containerHeightRatio = containerHeightRatio
        self.confirmBlock = confirmBlock
        self.cancelBlock = cancelBlock
        
        super.init()
        setupUI()
    }
    
    // MARK: - UI 搭建
    // 辅助方法：创建文本标签（简化代码）
    private func createLabel(text: String, font: UIFont, color: UIColor, numberOfLines: Int = 1) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = .center
        label.numberOfLines = numberOfLines
        label.adjustsFontSizeToFitWidth = false
        return label
    }
    
    private func setupUI() {
        maskView.tag = UnlinkConfirmPopup.kUnlinkConfirmMaskTag
        maskView.frame = UIScreen.main.bounds
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        maskView.alpha = 0
        maskView.isUserInteractionEnabled = true
        // ✅ 点击遮罩关闭弹窗，但需要排除 alertContainer 区域
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMaskTap(_:)))
        tapGesture.delegate = self // ✅ 设置代理以控制手势响应
        maskView.addGestureRecognizer(tapGesture)
        
        // 2. 弹窗容器（白色背景+圆角+阴影）
        alertContainer.backgroundColor = .white
        alertContainer.layer.cornerRadius = 20
        alertContainer.layer.masksToBounds = false
        alertContainer.layer.shadowColor = UIColor.black.cgColor
        alertContainer.layer.shadowOpacity = 0.1
        alertContainer.layer.shadowRadius = 10
        alertContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        alertContainer.alpha = 0
        alertContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        alertContainer.isUserInteractionEnabled = true
        
        // 添加容器到遮罩层
        maskView.addSubview(alertContainer)
        alertContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(305.0 / 375.0)
            make.height.equalToSuperview().multipliedBy(containerHeightRatio)
        }
        
        // 3. 未连接图标（中间显示，固定大小与其他空状态图片一致）
        let unlinkImageView = UIImageView()
        if let imageName = imageName, let unlinkImage = UIImage(named: imageName) {
            unlinkImageView.image = unlinkImage
        } else {
            // 如果没有指定图片，使用默认图片
            unlinkImageView.image = UIImage(named: "unlinkpopimage")
        }
        unlinkImageView.contentMode = .scaleAspectFit
        alertContainer.addSubview(unlinkImageView)
        unlinkImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(29)
            // ✅ 固定大小：与其他空状态图片一致（170.0 / 375.0）
            make.width.equalToSuperview().multipliedBy(252.0 / 305.0)
            make.height.equalTo(unlinkImageView.snp.width).multipliedBy(104.0 / 296.0)
        }
        
        // 4. 标题文字（在图标下方，如果有标题则显示）
        // ✅ 使用 lastView 跟踪最后一个视图，用于后续视图的约束定位
        var lastView: UIView = unlinkImageView
        
        if !title.isEmpty {
            let titleLabel = createLabel(
                text: title,
                font: UIFont(name: "SFCompactRounded-Bold", size: 16)!,
                color: .color(hexString: "#322D3A"),
                numberOfLines: 1
            )
            alertContainer.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(unlinkImageView.snp.bottom).offset(17)
                make.left.right.equalToSuperview().inset(20)
            }
            lastView = titleLabel
        }
        
        // 5. 描述文字（在标题下方；必须在按钮容器之前加入约束链，否则多行文案没有高度）
        if !message.isEmpty {
            let messageLabel = createLabel(
                text: message,
                font: UIFont(name: "SFCompactRounded-Medium", size: 14)!,
                color: .color(hexString: "#999DAB"),
                numberOfLines: 0
            )
            alertContainer.addSubview(messageLabel)
            let containerWidth = UIScreen.main.bounds.width * (305.0 / 375.0)
            messageLabel.preferredMaxLayoutWidth = containerWidth - 40
            messageLabel.snp.makeConstraints { make in
                make.top.equalTo(lastView.snp.bottom).offset(4)
                make.left.right.equalToSuperview().inset(20)
            }
            lastView = messageLabel
        }
            
        // 7. 按钮容器：贴在底部，上边距随 lastView（标题或 message）
        let buttonContainer = UIView()
        buttonContainer.isUserInteractionEnabled = true
        alertContainer.addSubview(buttonContainer)
        buttonContainer.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(lastView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(277.0 / 305.0)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-14)
        }

        
        // 取消按钮
        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.setTitleColor(.color(hexString: "#111111"), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        cancelButton.backgroundColor = .color(hexString: "#F9F9F9")
        cancelButton.isUserInteractionEnabled = true
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        cancelButton.layer.cornerRadius = 22
        cancelButton.clipsToBounds = true
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.color(hexString: "#999DAB").cgColor
        print("✅ [UnlinkConfirmPopup] 取消按钮已创建，target: \(self), action: cancelAction")
        buttonContainer.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(134.0 / 277.0)
            make.height.equalToSuperview()
        }
        
        // 确认按钮
        let confirmButton = UIButton(type: .custom)
        confirmButton.setTitle(confirmTitle, for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        confirmButton.backgroundColor = .color(hexString: "#000000")
        confirmButton.isUserInteractionEnabled = true
        confirmButton.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
        confirmButton.layer.cornerRadius = 22
        confirmButton.clipsToBounds = true
        print("✅ [UnlinkConfirmPopup] 确认按钮已创建，target: \(self), action: confirmAction")
        buttonContainer.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(134.0 / 277.0)
            make.height.equalToSuperview()
        }
        
        // ✅ 确保按钮在最上层，可以响应点击
        alertContainer.bringSubviewToFront(buttonContainer)
    }
    
    // MARK: - 对外暴露方法（显示弹窗）
    @discardableResult
    func show() -> Bool {
        // ✅ iOS 15+ 多 Scene 下 keyWindow 常为 nil，用前台 active window
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        guard let keyWindow = window else {
            print("❌ [UnlinkConfirmPopup] 无可用 window，弹窗未显示")
            return false
        }
        print("✅ [UnlinkConfirmPopup] 显示弹窗")
        keyWindow.addSubview(maskView)
        // 显示动画
        UIView.animate(withDuration: 0.25) {
            self.maskView.alpha = 1
            self.alertContainer.alpha = 1
            self.alertContainer.transform = .identity
        }
        return true
    }
    
    // MARK: - 内部事件处理
    @objc private func confirmAction() {
        print("✅ [UnlinkConfirmPopup] 确认按钮被点击")
        dismiss { [weak self] in
            self?.confirmBlock?()
        }
    }
    
    @objc private func cancelAction() {
        print("✅ [UnlinkConfirmPopup] 取消按钮被点击")
        dismiss { [weak self] in
            self?.cancelBlock?()
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // ✅ 如果点击的是 alertContainer 或其子视图，不响应遮罩层的手势
        let location = touch.location(in: maskView)
        if alertContainer.frame.contains(location) {
            return false
        }
        return true
    }
    
    @objc private func handleMaskTap(_ gesture: UITapGestureRecognizer) {
        dismiss { [weak self] in
            self?.cancelBlock?()
        }
    }
    
    /// 统一关闭弹窗：先动画移除遮罩，完成后再下一 runloop 执行回调，避免 present(CheekBoot) 与视图移除同帧导致残留/卡死
    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            self.maskView.alpha = 0
            self.alertContainer.alpha = 0
            self.alertContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.maskView.removeFromSuperview()
            DispatchQueue.main.async { completion?() }
        }
    }
    
    /// 链接成功后若「确认断开」弹窗仍残留在某 window，强制移除，避免关不掉、卡死
    static func forceRemoveFromAllWindows() {
        let tag = kUnlinkConfirmMaskTag
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for window in windows {
            if let mask = window.subviews.first(where: { $0.tag == tag }) {
                mask.removeFromSuperview()
            }
        }
    }
}

