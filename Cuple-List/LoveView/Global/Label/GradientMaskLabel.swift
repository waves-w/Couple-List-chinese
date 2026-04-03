//
//  GradientMaskLabel.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

class GradientMaskLabel: UIView {
    
    /// 显示的文本
    var text: String = "" {
        didSet {
            updateTextLayer()
            invalidateIntrinsicContentSize() // 刷新 intrinsic 尺寸，适配 Auto Layout
            setNeedsLayout()
        }
    }
    
    /// 文字字体
    var font: UIFont = UIFont(name: "SFCompactRounded-Bold", size: 30)! {
        didSet {
            updateTextLayer()
            invalidateIntrinsicContentSize()
        }
    }
    
    /// 文字颜色 (仅用于掩码 alpha 通道，实际显示为渐变)
    var textColor: UIColor = .white {
        didSet { updateTextLayer() }
    }
    
    /// 渐变的起始颜色
    var gradientStartColor: UIColor = .red {
        didSet { updateGradientLayer() }
    }
    
    /// 渐变的结束颜色
    var gradientEndColor: UIColor = .blue {
        didSet { updateGradientLayer() }
    }
    
    /// 渐变的方向 (默认是从左到右)
    var gradientDirection: (start: CGPoint, end: CGPoint) = (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5)) {
        didSet { updateGradientLayer() }
    }
    
    /// 最大显示行数 (0 表示无限制)
    var numberOfLines: Int = 1 {
        didSet { updateTextLayer() }
    }
    
    /// 文本对齐方式
    var textAlignment: NSTextAlignment = .center {
        didSet { updateTextLayer() }
    }
    
    /// 单行时宽度不足则缩小字号，相对 `font.pointSize` 的最小比例（与 UILabel.minimumScaleFactor 一致）
    var minimumScaleFactor: CGFloat = 0.35
    
    // MARK: - 内部图层
    private let gradientLayer = CAGradientLayer()
    private let textLayer = CATextLayer()
    
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
        // 1. 配置文字图层 (textLayer)
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale // 高清显示
        textLayer.isWrapped = false
        
        // 2. 配置渐变图层 (gradientLayer)
        gradientLayer.frame = bounds
        gradientLayer.mask = textLayer // 文字作为渐变掩码
        layer.addSublayer(gradientLayer)
        
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // 3. 初始更新
        updateTextLayer()
        updateGradientLayer()
    }
    
    // MARK: - 布局
    override func layoutSubviews() {
        super.layoutSubviews()
        // 确保图层尺寸与视图实际尺寸一致（适配约束变化、文本换行）
        gradientLayer.frame = bounds
        textLayer.frame = bounds
        // 重新计算文本布局（适配当前视图宽度）
        updateTextLayerLayout()
    }
    
    // MARK: - 文本图层更新
    private func updateTextLayer() {
        textLayer.string = text
        textLayer.font = font as CTFont
        textLayer.fontSize = font.pointSize
        textLayer.foregroundColor = textColor.cgColor
        
        // 对齐方式映射（CATextLayer.AlignmentMode 与 NSTextAlignment）
        switch textAlignment {
        case .left: textLayer.alignmentMode = .left
        case .center: textLayer.alignmentMode = .center
        case .right: textLayer.alignmentMode = .right
        default: textLayer.alignmentMode = .center
        }
        
        updateTextLayerLayout()
    }
    
    /// 适配视图宽度和行数限制，重新计算文本布局
    private func updateTextLayerLayout() {
        guard !text.isEmpty else { return }
        
        let maxWidth = bounds.width
        let maxHeight: CGFloat = numberOfLines > 0 ? font.lineHeight * CGFloat(numberOfLines) : .greatestFiniteMagnitude
        
        // 首次布局或从 isHidden 恢复时 bounds 可能仍为 0，避免用错误尺寸写 CATextLayer；下一轮 layout 会再算
        guard maxWidth > 0.5, bounds.height > 0.5 else { return }
        
        var fitFont = font
        if numberOfLines == 1, maxWidth > 0 {
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let natural = NSAttributedString(string: text, attributes: attrs).boundingRect(
                with: CGSize(width: .greatestFiniteMagnitude, height: maxHeight),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            if natural.width > maxWidth {
                let scale = maxWidth / natural.width
                let newSize = max(font.pointSize * minimumScaleFactor, font.pointSize * scale)
                fitFont = font.withSize(newSize)
            }
        }
        
        let attributes: [NSAttributedString.Key: Any] = [.font: fitFont]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        textLayer.font = fitFont as CTFont
        textLayer.fontSize = fitFont.pointSize
        
        let textRect = attributedText.boundingRect(
            with: CGSize(width: maxWidth, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        // 调整 textLayer 尺寸以匹配文本实际高度（避免渐变掩码裁剪）
        textLayer.frame = CGRect(x: 0, y: (bounds.height - textRect.height) / 2, width: maxWidth, height: textRect.height)
    }
    
    // MARK: - 渐变图层更新
    private func updateGradientLayer() {
        gradientLayer.colors = [gradientStartColor.cgColor, gradientEndColor.cgColor]
        gradientLayer.startPoint = gradientDirection.start
        gradientLayer.endPoint = gradientDirection.end
    }
    
    // MARK: - 适配 Auto Layout（关键：让视图能响应宽度约束，自动计算高度）
    override var intrinsicContentSize: CGSize {
        guard !text.isEmpty else { return .zero }
        
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        // 计算 intrinsic 尺寸（宽度设为无限时的自然尺寸，适配外部宽度约束）
        let maxWidth: CGFloat = .greatestFiniteMagnitude
        let maxHeight: CGFloat = numberOfLines > 0 ? font.lineHeight * CGFloat(numberOfLines) : .greatestFiniteMagnitude
        
        let textRect = attributedText.boundingRect(
            with: CGSize(width: maxWidth, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        return CGSize(width: textRect.width, height: textRect.height)
    }
    
    // MARK: - 支持外部触发刷新（如弹窗中分数变化后）
    func refresh() {
        updateTextLayer()
        updateGradientLayer()
        layoutIfNeeded()
    }
}
