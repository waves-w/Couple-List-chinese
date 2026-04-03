//
//  PointsViewBubbleAnimationManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

class PointsViewBubbleAnimationManager {
    
    // MARK: - Properties
    
    /// 蓝色液体动画管理器
    private let blueLiquidManager = LiquidAnimationManager()
    
    /// 粉色液体动画管理器
    private let pinkLiquidManager = LiquidAnimationManager()
    
    /// 标记是否已展示过气泡（每次进入页面时重置）
    private var hasShownBubbles: Bool = false
    
    // MARK: - Public Methods
    
    /// 更新蓝色视图的波浪和气泡动画
    /// - Parameters:
    ///   - targetView: 目标视图
    ///   - fillRatio: 填充比例 (0.0 - 1.0)
    ///   - animated: 是否需要动画
    func updateBlueViewAnimation(for targetView: UIImageView, fillRatio: CGFloat, animated: Bool = true) {
        updateAnimation(
            manager: blueLiquidManager,
            targetView: targetView,
            fillRatio: fillRatio,
            animated: animated
        )
    }
    
    /// 更新粉色视图的波浪和气泡动画
    /// - Parameters:
    ///   - targetView: 目标视图
    ///   - fillRatio: 填充比例 (0.0 - 1.0)
    ///   - animated: 是否需要动画
    func updatePinkViewAnimation(for targetView: UIImageView, fillRatio: CGFloat, animated: Bool = true) {
        updateAnimation(
            manager: pinkLiquidManager,
            targetView: targetView,
            fillRatio: fillRatio,
            animated: animated
        )
    }
    
    /// 清理所有气泡和波浪动画
    func cleanup() {
        blueLiquidManager.cleanup()
        pinkLiquidManager.cleanup()
        hasShownBubbles = false
    }
    
    /// 重置气泡显示标记（用于页面重新进入时）
    func resetBubbleFlag() {
        hasShownBubbles = false
        blueLiquidManager.resetBubbleFlag()
        pinkLiquidManager.resetBubbleFlag()
    }
    
    // MARK: - Private Methods
    
    /// 更新动画（内部统一方法）
    private func updateAnimation(
        manager: LiquidAnimationManager,
        targetView: UIImageView,
        fillRatio: CGFloat,
        animated: Bool
    ) {
        guard targetView.bounds.width > 0 && targetView.bounds.height > 0 else { return }
        
        let clampedRatio = max(0, min(1, fillRatio))
        
        // ✅ 如果不需要动画，直接更新
        if !animated {
            manager.updateWaveAndBubbles(
                for: targetView,
                fillRatio: clampedRatio,
                shouldShowBubbles: !hasShownBubbles
            )
            return
        }
        
        // ✅ 动画更新：先更新波浪，动画完成后创建气泡
        manager.updateWaveAndBubbles(
            for: targetView,
            fillRatio: clampedRatio,
            shouldShowBubbles: !hasShownBubbles
        )
        
        // ✅ 标记已展示过气泡（只在首次动画时）
        if !hasShownBubbles {
            hasShownBubbles = true
        }
    }
}






