//
//  BorderGradientView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa

class SettingBorderGradientView: UIView {
    
    // 1. 用于生成渐变色的图层 (覆盖整个 View)
    private let gradientLayer = CAGradientLayer()
    
    // 2. 用于定义边框形状的图层 (用于裁剪/蒙版)
    private let maskLayer = CAShapeLayer()
    
    // 公开属性，用于自定义边框宽度和圆角
    var borderWidth: CGFloat = 1.0 {
        didSet {
            setNeedsLayout()
        }
    }
    
    var cornerRadius: CGFloat = 13 {
        didSet {
            setNeedsLayout()
        }
    }
    
    /// 是否使用鲜明渐变边框（AECBFF→CDB0FF 从上到下，不透明）。默认 false 为半透明样式
    var useVividGradient: Bool = false {
        didSet {
            updateGradientColors()
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    // MARK: - Layout
    
    private var lastMaskBounds: CGRect = .zero
    private var lastBorderWidth: CGFloat = -1
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let boundsChanged = lastMaskBounds != bounds
        let borderWidthChanged = lastBorderWidth != borderWidth
        guard boundsChanged || borderWidthChanged else { return }
        lastMaskBounds = bounds
        lastBorderWidth = borderWidth
        gradientLayer.frame = bounds
        updateMask()
    }
    
    // MARK: - Setup
    
    private func setupLayers() {
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0) // 从上
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)   // 到下
        
        layer.addSublayer(gradientLayer)
        gradientLayer.mask = maskLayer
        
        self.backgroundColor = .white
        updateGradientColors()
    }
    
    private func updateGradientColors() {
        if useVividGradient {
            gradientLayer.colors = [
                UIColor.color(hexString: "#AECBFF").cgColor,
                UIColor.color(hexString: "#CDB0FF").cgColor
            ]
        } else {
            gradientLayer.colors = [
                UIColor.color(hexString: "#AECBFF").withAlphaComponent(0.15).cgColor,
                UIColor.color(hexString: "#CDB0FF").withAlphaComponent(0.15).cgColor
            ]
        }
    }
    
    private func updateMask() {
        // 创建外层路径 (视图的完整圆角矩形)
        let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        
        // 创建内层路径 (比视图小一个 borderWidth 的圆角矩形)
        let innerRect = bounds.insetBy(dx: borderWidth, dy: borderWidth)
        let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius - borderWidth)
        
        // 将内层路径添加到外层路径中，形成镂空效果 (Odd-Even Fill Rule)
        outerPath.append(innerPath)
        
        // 配置蒙版图层
        maskLayer.path = outerPath.cgPath
        maskLayer.fillRule = .evenOdd // 关键：使用 evenOdd 规则创建镂空
        maskLayer.fillColor = UIColor.black.cgColor // 蒙版颜色必须是不透明的
    }
}
