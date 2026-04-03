//
//  BeforeUnlinkConfirmPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class BeforeUnlinkConfirmPopup: NSObject, UIGestureRecognizerDelegate {
    typealias ConfirmBlock = () -> Void
    typealias CancelBlock = () -> Void
    
    private var confirmBlock: ConfirmBlock?
    private var cancelBlock: CancelBlock?
    
    private let maskView = UIView()
    private let alertContainer = UIView()
    
    private static let iconImageName = "user_x"
    private static let titleText = "Before you continue"
    private static let subtitleText = "Once the connection is removed."
    private static let messageText = """
    • Shared tasks will stop syncing
    • Points will become separate
    • Shared wishlists will no longer update
    • Anniversaries will remain only in your own account
    """
    private static let cancelTitle = "Cancel"
    private static let confirmTitle = "Continue"
    
    init(confirmBlock: @escaping ConfirmBlock, cancelBlock: CancelBlock? = nil) {
        self.confirmBlock = confirmBlock
        self.cancelBlock = cancelBlock
        super.init()
        setupUI()
    }
    
    private func setupUI() {
        maskView.frame = UIScreen.main.bounds
        maskView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        maskView.alpha = 0
        maskView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMaskTap(_:)))
        tapGesture.delegate = self
        maskView.addGestureRecognizer(tapGesture)
        
        alertContainer.backgroundColor = .white
        alertContainer.layer.cornerRadius = 22
        alertContainer.layer.masksToBounds = false
        alertContainer.layer.shadowColor = UIColor.black.cgColor
        alertContainer.layer.shadowOpacity = 0.1
        alertContainer.layer.shadowRadius = 10
        alertContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        alertContainer.alpha = 0
        alertContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        alertContainer.isUserInteractionEnabled = true
        maskView.addSubview(alertContainer)
        alertContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(305.0 / 375.0)
            make.height.equalToSuperview().multipliedBy(305.0 / 812.0)
        }
        
        // 图标
        let iconView = UIImageView(image: UIImage(named: Self.iconImageName))
        iconView.contentMode = .scaleAspectFit
        alertContainer.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(24)
            make.width.equalTo(44)
            make.height.equalTo(44)
        }
        
        // 标题
        let titleLabel = UILabel()
        titleLabel.text = Self.titleText
        titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
        titleLabel.textColor = .color(hexString: "#322D3A")
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        alertContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(20)
        }
        
        // 副标题
        let subtitleLabel = UILabel()
        subtitleLabel.text = Self.subtitleText
        subtitleLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        subtitleLabel.textColor = .color(hexString: "#8A8E9D")
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1
        alertContainer.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.left.right.equalToSuperview().inset(20)
        }
        
        // 说明列表
        let messageLabel = UILabel()
        messageLabel.text = Self.messageText
        messageLabel.font = UIFont(name: "SFCompactRounded-Medium", size: 14)
        messageLabel.textColor = .color(hexString: "#999DAB")
        messageLabel.textAlignment = .left
        messageLabel.numberOfLines = 0
        let containerWidth = UIScreen.main.bounds.width * (305.0 / 375.0)
        messageLabel.preferredMaxLayoutWidth = containerWidth - 20
        alertContainer.addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(30)
        }
        
        // 按钮容器
        let buttonContainer = UIView()
        buttonContainer.isUserInteractionEnabled = true
        alertContainer.addSubview(buttonContainer)
        buttonContainer.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(messageLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(277.0 / 305.0)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle(Self.cancelTitle, for: .normal)
        cancelButton.setTitleColor(.color(hexString: "#111111"), for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        cancelButton.backgroundColor = .color(hexString: "#F9F9F9")
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        cancelButton.layer.cornerRadius = 20
        cancelButton.clipsToBounds = true
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.color(hexString: "#999DAB").cgColor
        buttonContainer.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(134.0 / 277.0)
            make.height.equalToSuperview()
        }
        
        let confirmButton = UIButton(type: .custom)
        confirmButton.setTitle(Self.confirmTitle, for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        confirmButton.backgroundColor = .color(hexString: "#000000")
        confirmButton.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
        confirmButton.layer.cornerRadius = 20
        confirmButton.clipsToBounds = true
        buttonContainer.addSubview(confirmButton)
        confirmButton.snp.makeConstraints { make in
            make.right.centerY.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(134.0 / 277.0)
            make.height.equalToSuperview()
        }
        
        alertContainer.bringSubviewToFront(buttonContainer)
    }
    
    @discardableResult
    func show() -> Bool {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        guard let keyWindow = window else { return false }
        keyWindow.addSubview(maskView)
        UIView.animate(withDuration: 0.25) {
            self.maskView.alpha = 1
            self.alertContainer.alpha = 1
            self.alertContainer.transform = .identity
        }
        return true
    }
    
    @objc private func confirmAction() {
        dismiss { [weak self] in
            self?.confirmBlock?()
        }
    }
    
    @objc private func cancelAction() {
        dismiss { [weak self] in
            self?.cancelBlock?()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: maskView)
        return !alertContainer.frame.contains(location)
    }
    
    @objc private func handleMaskTap(_ gesture: UITapGestureRecognizer) {
        dismiss { [weak self] in
            self?.cancelBlock?()
        }
    }
    
    private func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            self.maskView.alpha = 0
            self.alertContainer.alpha = 0
            self.alertContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.maskView.removeFromSuperview()
            completion?()
        }
    }
}
