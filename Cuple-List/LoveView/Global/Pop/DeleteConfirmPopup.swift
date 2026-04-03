//
//  DeleteConfirmPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class DeleteConfirmPopup: NSObject, UIGestureRecognizerDelegate {
    // 回调闭包：确认删除时触发，取消时可选
    typealias ConfirmBlock = () -> Void
    typealias CancelBlock = () -> Void
    
    private var confirmBlock: ConfirmBlock?
    private var cancelBlock: CancelBlock?
    
    // 弹窗核心视图
    private let maskView = UIView()
    private let alertContainer = UIView()
    /// 确认按钮及其渐变层（用于布局后更新渐变 frame）
    private weak var confirmButton: UIButton?
    private var confirmGradientLayer: CAGradientLayer?
    
    // 自定义配置参数（外部可传，默认有默认值）
    private var title: String
    private var message: String
    private var imageName: String?
    private var cancelTitle: String
    private var confirmTitle: String
    
    // MARK: - 初始化（支持自定义参数）
    init(title: String = "Confirm Deletion",
         message: String = "Are you sure you want to delete this item?",
         imageName: String? = "delete_icon", // 默认为你的删除图片
         cancelTitle: String = "Cancel",
         confirmTitle: String = "Delete",
         confirmBlock: @escaping ConfirmBlock,
         cancelBlock: CancelBlock? = nil) {
        
        self.title = title
        self.message = message
        self.imageName = imageName
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.confirmBlock = confirmBlock
        self.cancelBlock = cancelBlock
        
        super.init()
        setupUI()
    }
    
    // MARK: - UI 搭建
    private func setupUI() {
        // 1. 遮罩层（全屏半透明）
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
        alertContainer.layer.cornerRadius = 22
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
            make.height.greaterThanOrEqualTo(180)
        }
        
        // 3. 删除图标（中间显示）
        let deleteImageView = UIImageView()
        if let imageName = imageName, let deleteImage = UIImage(named: imageName) {
            deleteImageView.image = deleteImage
        } else {
            // 如果没有指定图片，使用系统删除图标
            deleteImageView.image = UIImage(systemName: "trash")?.withTintColor(.color(hexString: "#FF3B30"), renderingMode: .alwaysOriginal)
        }
        deleteImageView.contentMode = .scaleAspectFit
        alertContainer.addSubview(deleteImageView)
        deleteImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(16)
            make.width.height.equalTo(44) // 删除图标大小
        }
        
        // 4. 标题文字（在图标下方，如果有标题则显示）
        var lastView: UIView = deleteImageView
        if !title.isEmpty {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont(name: "SFCompactRounded-Bold", size: 16)
            titleLabel.textColor = .color(hexString: "#111111")
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 1
            alertContainer.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(deleteImageView.snp.bottom).offset(7)
                make.left.right.equalToSuperview().inset(20)
            }
            lastView = titleLabel
        }
        
        // 5. 描述文字（在标题下方，如果有描述则显示）
        if !message.isEmpty {
            let messageLabel = UILabel()
            messageLabel.text = message
            messageLabel.font = UIFont(name: "SFCompactRounded-Regular", size: 14)
            messageLabel.textColor = .color(hexString: "#666666")
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            alertContainer.addSubview(messageLabel)
            messageLabel.snp.makeConstraints { make in
                if !title.isEmpty {
                    make.top.equalTo(lastView.snp.bottom).offset(8)
                } else {
                    make.top.equalTo(deleteImageView.snp.bottom).offset(20)
                }
                make.left.right.equalToSuperview().inset(20)
            }
            lastView = messageLabel
        }
        
        // 7. 按钮容器（用于居中布局）
        let buttonContainer = UIView()
        buttonContainer.isUserInteractionEnabled = true
        alertContainer.addSubview(buttonContainer)
        buttonContainer.snp.makeConstraints { make in
            make.top.equalTo(lastView.snp.bottom).offset(30)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(277.0 / 305.0)
            make.height.equalTo(40)
            make.bottom.equalToSuperview().offset(-14)
        }
        
        // 取消按钮
        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        cancelButton.backgroundColor = .color(hexString: "#F9F9F9")
        cancelButton.isUserInteractionEnabled = true
        cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        cancelButton.layer.cornerRadius = 20
        cancelButton.clipsToBounds = true
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.color(hexString: "#999DAB").cgColor
        cancelButton.adjustsImageWhenHighlighted = false
        cancelButton.showsTouchWhenHighlighted = false
        let cancelTitleColor = UIColor.color(hexString: "#111111")
        cancelButton.setTitleColor(cancelTitleColor, for: .normal)
        cancelButton.setTitleColor(cancelTitleColor, for: .highlighted)
        buttonContainer.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(134.0 / 277.0)
            make.height.equalToSuperview()
        }
        
        // 确认删除按钮（从上到下渐变 #FF754E → #FF5E55）
        let confirmButton = UIButton(type: .custom)
        confirmButton.setTitle(confirmTitle, for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "SFCompactRounded-Bold", size: 15)
        confirmButton.backgroundColor = .clear
        confirmButton.isUserInteractionEnabled = true
        confirmButton.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
        confirmButton.layer.cornerRadius = 20
        confirmButton.clipsToBounds = true
        confirmButton.adjustsImageWhenHighlighted = false
        confirmButton.showsTouchWhenHighlighted = false
        confirmButton.setTitleColor(.white, for: .highlighted)
        confirmButton.setTitleColor(.white, for: .selected)
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.color(hexString: "#FF754E").cgColor,
            UIColor.color(hexString: "#FF5E55").cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.cornerRadius = 20
        confirmButton.layer.insertSublayer(gradientLayer, at: 0)
        self.confirmButton = confirmButton
        self.confirmGradientLayer = gradientLayer
        print("✅ [DeleteConfirmPopup] 确认删除按钮已创建，target: \(self), action: confirmAction")
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
    
    /// 避免修改 gradientLayer.frame 时隐式 CA 动画导致 Delete 按钮渐变「抽动」
    private func layoutConfirmGradientFrameIfNeeded() {
        guard let btn = confirmButton, let gl = confirmGradientLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gl.frame = btn.bounds
        CATransaction.commit()
    }
    
    // MARK: - 对外暴露方法（显示弹窗）
    func show() {
        guard let keyWindow = UIApplication.shared.keyWindow else {
            print("❌ [DeleteConfirmPopup] keyWindow 为 nil")
            return
        }
        print("✅ [DeleteConfirmPopup] 显示弹窗")
        keyWindow.addSubview(maskView)
        maskView.layoutIfNeeded()
        layoutConfirmGradientFrameIfNeeded()
        maskView.alpha = 0
        alertContainer.alpha = 0
        UIView.animate(withDuration: 0.25) {
            self.maskView.alpha = 1
            self.alertContainer.alpha = 1
        }
    }
    
    // MARK: - 内部事件处理
    @objc private func confirmAction() {
        print("✅ [DeleteConfirmPopup] 确认删除按钮被点击")
        confirmBlock?() // 触发确认回调
        dismiss()
    }
    
    @objc private func cancelAction() {
        print("✅ [DeleteConfirmPopup] 取消按钮被点击")
        cancelBlock?() // 触发取消回调
        dismiss()
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
        // ✅ 点击遮罩层，关闭弹窗
        dismiss()
    }
    
    @objc private func dismiss() {
        UIView.animate(withDuration: 0.25, animations: {
            self.maskView.alpha = 0
            self.alertContainer.alpha = 0
        }) { _ in
            self.maskView.removeFromSuperview()
        }
    }
}
