//
//  LiquidAnimationManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

/// 液体动画管理器：管理波浪和气泡动画效果
class LiquidAnimationManager {
    
    // MARK: - Properties
    
    private var waveLayer: CAShapeLayer?
    private var bubbles: [CALayer] = []
    private var hasShownBubbles: Bool = false
    
    // MARK: - Public Methods
    
    /// 更新波浪和气泡效果
    /// - Parameters:
    ///   - targetView: 目标视图
    ///   - fillRatio: 填充比例 (0.0 - 1.0)
    ///   - shouldShowBubbles: 是否显示气泡（默认只在首次进入页面时显示）
    func updateWaveAndBubbles(for targetView: UIImageView, fillRatio: CGFloat, shouldShowBubbles: Bool = false) {
        guard targetView.bounds.width > 0 && targetView.bounds.height > 0 else { return }
        
        let totalHeight = targetView.bounds.height
        let totalWidth = targetView.bounds.width
        let fillHeight = totalHeight * fillRatio
        
        // ✅ 如果填充为0，移除波浪和气泡
        if fillRatio <= 0 {
            cleanup()
            return
        }
        
        // ✅ 移除波浪线（不再创建波浪层）
        // setupWaveLayer(for: targetView, totalWidth: totalWidth, totalHeight: totalHeight, fillHeight: fillHeight)
        
        // ✅ 只在需要时创建气泡
        if shouldShowBubbles && !hasShownBubbles && fillRatio > 0 {
            createBubbles(for: targetView, totalWidth: totalWidth, totalHeight: totalHeight, fillHeight: fillHeight)
            hasShownBubbles = true
        }
    }
    
    /// 清理所有动画和图层
    func cleanup() {
        // ✅ 清理气泡
        bubbles.forEach { bubble in
            bubble.removeAllAnimations()
            bubble.removeFromSuperlayer()
        }
        bubbles.removeAll()
        
        // ✅ 清理波浪动画和图层（如果存在）
        if let waveLayer = waveLayer {
            waveLayer.removeAllAnimations()
            waveLayer.removeFromSuperlayer()
            self.waveLayer = nil
        }
        
        // ✅ 重置标记
        hasShownBubbles = false
    }
    
    /// 重置气泡显示标记（用于页面重新进入时）
    func resetBubbleFlag() {
        hasShownBubbles = false
    }
    
    // MARK: - Private Methods
    
    /// 设置波浪层
    private func setupWaveLayer(for targetView: UIImageView, totalWidth: CGFloat, totalHeight: CGFloat, fillHeight: CGFloat) {
        // ✅ 创建或获取波浪层
        if waveLayer == nil {
            let layer = CAShapeLayer()
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
            layer.lineWidth = 2.0
            targetView.layer.addSublayer(layer)
            waveLayer = layer
        }
        
        guard let waveLayer = waveLayer else { return }
        
        // ✅ 创建波浪路径（在液体顶部，只是一条波浪线）
        let waveY = totalHeight - fillHeight
        let wavePath = createWaveLinePath(width: totalWidth, y: waveY, amplitude: 3.0, frequency: 0.02)
        waveLayer.path = wavePath.cgPath
        waveLayer.frame = targetView.bounds
        
        // ✅ 波浪动画（持续波动）- 移除旧动画并重新创建，确保位置正确
        waveLayer.removeAnimation(forKey: "waveAnimation")
        let waveAnimation = CABasicAnimation(keyPath: "path")
        waveAnimation.fromValue = createWaveLinePath(width: totalWidth, y: waveY, amplitude: 3.0, frequency: 0.02, phase: 0).cgPath
        waveAnimation.toValue = createWaveLinePath(width: totalWidth, y: waveY, amplitude: 3.0, frequency: 0.02, phase: .pi * 2).cgPath
        waveAnimation.duration = 2.0
        waveAnimation.repeatCount = .infinity
        waveAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        waveLayer.add(waveAnimation, forKey: "waveAnimation")
    }
    
    /// 创建气泡
    private func createBubbles(for targetView: UIImageView, totalWidth: CGFloat, totalHeight: CGFloat, fillHeight: CGFloat) {
        let fillRatio = fillHeight / totalHeight
        let bubbleColor = UIColor.white.withAlphaComponent(0.4).cgColor
        
        // ✅ 创建新气泡（在液体区域内随机分布）
        let bubbleCount = Int(fillRatio * 5) + 2 // 根据填充比例创建气泡
        for _ in 0..<bubbleCount {
            let bubble = CALayer()
            let size = CGFloat.random(in: 2...5)
            bubble.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            bubble.cornerRadius = size / 2
            bubble.backgroundColor = bubbleColor
            bubble.opacity = Float.random(in: 0.3...0.6)
            
            // ✅ 气泡初始位置：在液体底部附近随机分布
            let x = CGFloat.random(in: size...(totalWidth - size))
            let y = totalHeight - size // ✅ 初始位置在底部
            bubble.position = CGPoint(x: x, y: y)
            
            targetView.layer.addSublayer(bubble)
            bubbles.append(bubble)
            
            // ✅ 创建气泡动画
            setupBubbleAnimation(bubble: bubble, x: x, totalHeight: totalHeight, fillHeight: fillHeight, size: size)
        }
    }
    
    /// 设置气泡动画
    private func setupBubbleAnimation(bubble: CALayer, x: CGFloat, totalHeight: CGFloat, fillHeight: CGFloat, size: CGFloat) {
        // ✅ 气泡上升动画（从底部上升到液体顶部，然后淡出消失）
        let bubbleAnimation = CABasicAnimation(keyPath: "position.y")
        let startY = totalHeight - size // ✅ 从底部开始
        let waveTopY = totalHeight - fillHeight
        let endY = max(waveTopY - size, waveTopY * 0.1) // ✅ 上升到液体顶部
        bubbleAnimation.fromValue = startY
        bubbleAnimation.toValue = endY
        bubbleAnimation.duration = Double.random(in: 2.5...4.5)
        bubbleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        bubbleAnimation.fillMode = .forwards
        bubbleAnimation.isRemovedOnCompletion = false
        
        // ✅ 气泡左右摆动（只在上升过程中）
        let xAnimation = CAKeyframeAnimation(keyPath: "position.x")
        let swingAmount = CGFloat.random(in: 3...8)
        xAnimation.values = [x, x + swingAmount, x - swingAmount, x]
        xAnimation.keyTimes = [0, 0.33, 0.66, 1.0]
        xAnimation.duration = bubbleAnimation.duration
        xAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        xAnimation.fillMode = .forwards
        xAnimation.isRemovedOnCompletion = false
        
        // ✅ 气泡淡出动画（到达顶部时淡出）
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = bubble.opacity
        fadeAnimation.toValue = 0.0
        fadeAnimation.duration = bubbleAnimation.duration * 0.3 // ✅ 最后30%的时间淡出
        fadeAnimation.beginTime = bubbleAnimation.duration * 0.7 // ✅ 从70%处开始淡出
        fadeAnimation.fillMode = .forwards
        fadeAnimation.isRemovedOnCompletion = false
        
        let bubbleGroup = CAAnimationGroup()
        bubbleGroup.animations = [bubbleAnimation, xAnimation, fadeAnimation]
        bubbleGroup.duration = bubbleAnimation.duration
        bubbleGroup.fillMode = .forwards
        bubbleGroup.isRemovedOnCompletion = false
        
        // ✅ 动画完成后移除气泡
        let delegate = BubbleAnimationDelegate { [weak bubble, weak self] in
            guard let bubble = bubble else { return }
            bubble.removeFromSuperlayer()
            self?.bubbles.removeAll { $0 == bubble }
        }
        bubbleGroup.delegate = delegate
        objc_setAssociatedObject(bubble, &BubbleAnimationKeys.animationDelegate, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        bubble.add(bubbleGroup, forKey: "bubbleAnimation")
    }
    
    /// 创建波浪线路径（只在液体顶部画一条波浪线）
    private func createWaveLinePath(width: CGFloat, y: CGFloat, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat = 0) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: y + amplitude * sin(phase)))
        
        let step: CGFloat = 1.0
        for x in stride(from: 0, through: width, by: step) {
            let waveY = y + amplitude * sin(frequency * x + phase)
            path.addLine(to: CGPoint(x: x, y: waveY))
        }
        
        return path
    }
}

// MARK: - Animation Delegate

private class BubbleAnimationDelegate: NSObject, CAAnimationDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            completion()
        }
    }
}

private struct BubbleAnimationKeys {
    static var animationDelegate = "bubbleAnimationDelegate"
}

