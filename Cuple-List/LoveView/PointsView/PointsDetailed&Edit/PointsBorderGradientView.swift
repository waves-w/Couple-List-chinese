//
//  PointsBorderGradientView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit
import ReactiveSwift
import ReactiveCocoa

class PointsBorderGradientView: UIView {
    
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
    
    var cornerRadius: CGFloat = 22 {
        didSet {
            setNeedsLayout()
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 1. 更新渐变图层的尺寸以匹配视图
        gradientLayer.frame = bounds
        
        // 2. 更新蒙版图层 (maskLayer) 的形状
        updateMask()
    }
    
    // MARK: - Setup
    
    private func setupLayers() {
        // 配置渐变色
        gradientLayer.colors = [
            UIColor.color(hexString: "#AECBFF").withAlphaComponent(0.15).cgColor, // 示例颜色 1
            UIColor.color(hexString: "#CDB0FF").withAlphaComponent(0.15).cgColor  // 示例颜色 2
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0) // 从左上角开始
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)   // 到右下角结束
        
        // 将渐变图层添加到视图的 layer 上
        layer.addSublayer(gradientLayer)
        
        // 将 CAShapeLayer 设置为渐变图层的蒙版
        gradientLayer.mask = maskLayer
        
        // 视图本身的背景色可以设置为白色或透明
        self.backgroundColor = .white
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
