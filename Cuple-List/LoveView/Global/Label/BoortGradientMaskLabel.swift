//
//  BoortGradientMaskLabel.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

class BootGradientMaskLabel: UIView {
    
    /// ✅ 核心新增：字符间距属性（和StrokeShadowLabel完全一致）
    var letterSpacing: CGFloat = 0.0 {
        didSet {
            if oldValue != letterSpacing {
                updateTextLayer()
                invalidateIntrinsicContentSize()
            }
        }
    }
    
    /// 显示的文本
    var text: String = "" {
        didSet {
            updateTextLayer()
            invalidateIntrinsicContentSize() // 刷新 intrinsic 尺寸，适配 Auto Layout
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
        
        // 2. 配置渐变图层 (gradientLayer)
        gradientLayer.frame = bounds
        gradientLayer.mask = textLayer // 文字作为渐变掩码
        layer.addSublayer(gradientLayer)
        
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
    
    // MARK: - ✅ 核心修改：重构文本图层更新，集成「字符间距+渐变+所有样式」
    private func updateTextLayer() {
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
        
        // ✅ 核心逻辑：生成「带字符间距」的富文本，赋值给textLayer
        let attrString = NSMutableAttributedString(string: text)
        // 1. 基础字体属性
        attrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        // 2. 核心：添加字符间距属性
        if letterSpacing > 0 {
            attrString.addAttribute(.kern, value: letterSpacing, range: NSRange(location: 0, length: text.count))
        }
        // 赋值富文本到图层
        textLayer.string = attrString
        
        updateTextLayerLayout()
    }
    
    /// 适配视图宽度和行数限制，重新计算文本布局
    private func updateTextLayerLayout() {
        guard !text.isEmpty else { return }
        
        // ✅ 适配字符间距：用富文本计算真实尺寸，避免间距导致的裁剪/错位
        let attrString = NSMutableAttributedString(string: text)
        attrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        if letterSpacing > 0 {
            attrString.addAttribute(.kern, value: letterSpacing, range: NSRange(location: 0, length: text.count))
        }
        
        // 计算文本在当前视图宽度下的实际尺寸
        let maxWidth = bounds.width
        let maxHeight: CGFloat = numberOfLines > 0 ? font.lineHeight * CGFloat(numberOfLines) : .greatestFiniteMagnitude
        
        let textRect = attrString.boundingRect(
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
    
    // MARK: - 适配 Auto Layout（兼容字符间距，计算真实intrinsic尺寸）
    override var intrinsicContentSize: CGSize {
        guard !text.isEmpty else { return .zero }
        
        // ✅ 适配字符间距：用富文本计算自然尺寸
        let attrString = NSMutableAttributedString(string: text)
        attrString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        if letterSpacing > 0 {
            attrString.addAttribute(.kern, value: letterSpacing, range: NSRange(location: 0, length: text.count))
        }
        
        let maxWidth: CGFloat = .greatestFiniteMagnitude
        let maxHeight: CGFloat = numberOfLines > 0 ? font.lineHeight * CGFloat(numberOfLines) : .greatestFiniteMagnitude
        
        let textRect = attrString.boundingRect(
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
