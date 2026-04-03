//
//  DualButtonView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class DualButtonView: UIView {
    
    // 顶部标题标签
    public let titleLabel = UILabel()
    
    // 左侧按钮
    // 使用 modern UIButton.Configuration 样式
    public let leftButton = UIButton()
    
    // 右侧按钮
    public let rightButton = UIButton()
    
    // 按钮容器
    private let buttonStackView = UIStackView()
    
    public var leftButtonImageView: UIImageView!
    public var rightButtonImageView: UIImageView!
    
    
    init(title: String,
         leftButtonTitle: String,
         leftButtonImage: UIImage?,
         rightButtonTitle: String,
         rightButtonImage: UIImage?) {
        super.init(frame: .zero)
        titleLabel.text = title
        configureLeftButton(title: leftButtonTitle, image: leftButtonImage)
        configureRightButton(title: rightButtonTitle, image: rightButtonImage)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 配置左侧按钮（主按钮样式）
    private func configureLeftButton(title: String, image: UIImage?) {
        leftButton.backgroundColor = .color(hexString: "#FBFBFB")
        leftButton.layer.cornerRadius = 12
        leftButton.clipsToBounds = true
        leftButton.isUserInteractionEnabled = true // 确保可点击
        
        // 添加内部子视图（标题+图片）
        addContentToButton(button: leftButton, title: title, image: image, textColor: .color(hexString: "#322D3A"))
    }
    
    // 配置右侧按钮（次要按钮样式）
    private func configureRightButton(title: String, image: UIImage?) {
        rightButton.backgroundColor = .color(hexString: "#FBFBFB")
        rightButton.layer.cornerRadius = 12
        rightButton.clipsToBounds = true
        rightButton.isUserInteractionEnabled = true
        
        // 添加内部子视图（标题+图片）
        addContentToButton(button: rightButton, title: title, image: image, textColor: .color(hexString: "#322D3A"))
    }
    
    // 给按钮添加左侧标题+右侧图片
    private func addContentToButton(button: UIButton, title: String, image: UIImage?, textColor: UIColor) {
        // 清除默认内容（避免与自定义子视图冲突）
        button.setTitle(nil, for: .normal)
        button.setImage(nil, for: .normal)
        
        // 内部容器（统一管理标题和图片）
        let contentContainer = UIView()
        contentContainer.backgroundColor = .clear
        contentContainer.isUserInteractionEnabled = false
        button.addSubview(contentContainer)
        contentContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 左侧标题
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = textColor
        contentContainer.addSubview(titleLabel)
        
        // 右侧图片
        let imageView = UIImageView()
        imageView.image = UIImage(named: "assignUnselect")
        imageView.contentMode = .scaleAspectFit
        contentContainer.addSubview(imageView)
        
        // 布局约束
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(12) // 左内边距
        }
        
        imageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-12) // 右内边距
        }
        
        if button === leftButton {
            leftButtonImageView = imageView
        } else if button === rightButton {
            rightButtonImageView = imageView
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        // 配置标题标签
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label // 适配深色/浅色模式
        self.addSubview(titleLabel)
        
        // 配置按钮栈视图
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 10 // 按钮之间的间距
        buttonStackView.distribution = .fillEqually // 确保两个按钮宽度相同
        
        buttonStackView.addArrangedSubview(leftButton)
        buttonStackView.addArrangedSubview(rightButton)
        self.addSubview(buttonStackView)
    }
    
    private func setupConstraints() {
        // 1. 标题约束
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.left.equalTo(14)
        }
        
        // 2. 按钮栈视图约束
        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(14)
            make.height.equalTo(36)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
}
