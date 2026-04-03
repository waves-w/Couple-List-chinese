//
//  StrokeShadowLabel.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class StrokeShadowLabel: UIView {//边框
    
    /// 显示的文本
    var text: String = "" {
        didSet { updateLabel() }
    }
    
    /// 文字字体
    var font: UIFont = UIFont(name: "SFCompactRounded-Bold", size: 23)! {
        didSet { updateLabel() }
    }
    
    /// 文字填充颜色
    var textColor: UIColor = .white {
        didSet { updateLabel() }
    }
    
    /// 描边颜色
    var strokeColor: UIColor = .white {
        didSet { updateLabel() }
    }
    
    /// 描边宽度（负值表示同时显示填充和描边，正值仅显示描边）
    var strokeWidth: CGFloat = -25.0 {
        didSet {
            //            // 当描边宽度改变时，同时调整内边距
            //            label.contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            updateLabel()
        }
    }
    
    // MARK: - 阴影相关可配置属性
    /// 阴影颜色
    var shadowColor: UIColor = .clear {
        didSet { updateLabel() }
    }
    
    /// 阴影偏移量
    var shadowOffset: CGSize = CGSize(width: 0, height: 0) { // 默认值改为(0,1)
        didSet { updateLabel() }
    }
    
    /// 阴影模糊半径
    var shadowBlurRadius: CGFloat = 0 { // 新增：阴影模糊半径
        didSet { updateLabel() }
    }
    
    // MARK: - 内部子视图（现在使用 BorderGradienLabel）
    private let label = BorderGradienLabel()
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        // 添加子视图
        addSubview(label)
        label.isUserInteractionEnabled = false
        label.textAlignment = .center
        label.numberOfLines = 1 // ✅ 默认单行
        label.clipsToBounds = false // 确保投影不被裁剪
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.35
        label.baselineAdjustment = .alignCenters
        label.contentInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateLabel()
    }
    
    // MARK: - 布局
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
    
    // MARK: - 核心更新方法
    private func updateLabel() {
        // 更新阴影属性
        label.layer.shadowColor = shadowColor.cgColor
        label.layer.shadowOffset = shadowOffset
        label.layer.shadowRadius = shadowBlurRadius // 应用模糊半径
        label.layer.shadowOpacity = 1.0 // 保持不透明，阴影透明度由shadowColor控制
        
        // 更新文字属性
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .strokeColor: strokeColor,
            .strokeWidth: strokeWidth,
        ]
        
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
        label.invalidateIntrinsicContentSize()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
    
    // MARK: - 适配 Auto Layout（返回 intrinsic 尺寸）
    override var intrinsicContentSize: CGSize {
        return label.intrinsicContentSize
    }
    
    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        label.invalidateIntrinsicContentSize()
    }
}

class BorderGradienLabel: UILabel {
    
    var contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
