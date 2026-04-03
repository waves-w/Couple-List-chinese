//
//  ViewGradientView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class ViewGradientView: UIView {
    
    // 懒加载渐变层 + 全局缓存，避免重复创建
    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        let color1 = UIColor.color(hexString: "#FFE7F7")
        let color2 = UIColor.color(hexString: "#E7E7FF")
        layer.colors = [
            color1.withAlphaComponent(0.25).cgColor,
            color2.withAlphaComponent(0.25).cgColor
        ]
        layer.locations = [0.0, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.masksToBounds = true // 适配圆角
        return layer
    }()
    
    // 标记是否已初始化渐变层（避免重复添加）
    private var isGradientLayerAdded = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        // 基础配置：背景透明，避免遮挡
        self.backgroundColor = .white
        // 异步初始化渐变层，不阻塞主线程
        DispatchQueue.main.async { [weak self] in
            self?.setupGradient()
        }
    }
    
    // 仅当 bounds 变化时更新渐变层，避免键盘弹出时整棵视图树重算带来的重复 layout 卡顿
    private var lastLayoutBounds: CGRect = .zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard lastLayoutBounds != bounds else { return }
        lastLayoutBounds = bounds
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = layer.cornerRadius
    }
    
    // 配置渐变层，保证完全覆盖
    private func setupGradient() {
        guard !isGradientLayerAdded else { return }
        
        // 将渐变层插入到最底层，不遮挡子视图
        layer.insertSublayer(gradientLayer, at: 0)
        isGradientLayerAdded = true
        
        // 强制刷新布局，确保渐变层立即适配当前视图尺寸
        gradientLayer.frame = bounds
        
        // 淡入动画：解决导航跳转时的生硬问题
        self.alpha = 0
        UIView.animate(withDuration: 0.15) {
            self.alpha = 1
        }
    }
    
    
    // MARK: - 兼容AutoLayout的强制刷新方法
    func refreshGradientFrame() {
        gradientLayer.frame = bounds
    }
}
