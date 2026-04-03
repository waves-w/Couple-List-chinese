//
//  PointsViewHeartMaskManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class PointsViewHeartMaskManager {
    
    // MARK: - Properties
    
    weak var pointsView: PointsView?
    private let bubbleAnimationManager: PointsViewBubbleAnimationManager
    
    // ✅ 保存矩形视图的底部约束，用于控制上下移动
    private var upblueViewBottomConstraint: Constraint?
    private var upinkViewBottomConstraint: Constraint?
    
    init(pointsView: PointsView, bubbleAnimationManager: PointsViewBubbleAnimationManager) {
        self.pointsView = pointsView
        self.bubbleAnimationManager = bubbleAnimationManager
    }
    
    // MARK: - Public Methods
    
    /// 设置蓝色视图的底部约束
    func setBlueViewBottomConstraint(_ constraint: Constraint?) {
        upblueViewBottomConstraint = constraint
    }
    
    /// 设置粉色视图的底部约束
    func setPinkViewBottomConstraint(_ constraint: Constraint?) {
        upinkViewBottomConstraint = constraint
    }
    
    /// 为容器视图设置固定的爱心遮罩
    func setupHeartMaskForContainer(_ containerView: UIImageView) {
        guard let maskImage = UIImage(named: "upheard"),
              containerView.bounds.width > 0 && containerView.bounds.height > 0 else {
            return
        }
        
        let maskLayer: CALayer
        if let existingMask = containerView.layer.mask {
            maskLayer = existingMask
        } else {
            maskLayer = CALayer()
            containerView.layer.mask = maskLayer
        }
        
        maskLayer.contents = maskImage.cgImage
        maskLayer.contentsGravity = .resizeAspect
        maskLayer.frame = containerView.bounds
    }
    
    /// 应用爱心填充动画
    /// - Parameters:
    ///   - maskView: 遮罩视图
    ///   - targetView: 目标视图（蓝色或粉色填充视图）
    ///   - fillRatio: 填充比例 (0.0 - 1.0)
    ///   - animated: 是否需要动画
    func applyHeartMask(maskView: UIImageView, targetView: UIImageView, fillRatio: CGFloat, animated: Bool = true) {
        guard targetView.bounds.width > 0 && targetView.bounds.height > 0,
              let containerView = targetView.superview else {
            return
        }
        
        let clampedRatio = max(0, min(1, fillRatio))
        let containerHeight = containerView.bounds.height
        
        // ✅ 计算矩形视图应该移动到的位置
        // fillRatio = 0 时，矩形完全在底部（隐藏）
        // fillRatio = 1 时，矩形完全填充（底部对齐）
        // 矩形需要向上移动的距离 = 容器高度 * (1 - fillRatio)
        let offsetY = containerHeight * (1 - clampedRatio)
        
        // ✅ 获取对应的约束
        let bottomConstraint: Constraint?
        guard let pointsView = pointsView else { return }
        
        if targetView == pointsView.upblueView {
            bottomConstraint = upblueViewBottomConstraint
        } else if targetView == pointsView.upinkView {
            bottomConstraint = upinkViewBottomConstraint
        } else {
            return
        }
        
        guard let constraint = bottomConstraint else { return }
        
        // ✅ 如果不需要动画，直接更新约束
        if !animated {
            constraint.update(offset: offsetY)
            containerView.layoutIfNeeded()
            
            // ✅ 更新波浪和气泡
            if targetView == pointsView.upblueView {
                bubbleAnimationManager.updateBlueViewAnimation(for: targetView, fillRatio: clampedRatio, animated: false)
            } else if targetView == pointsView.upinkView {
                bubbleAnimationManager.updatePinkViewAnimation(for: targetView, fillRatio: clampedRatio, animated: false)
            }
            return
        }
        
        // ✅ 动画更新约束（平滑缓动，无回弹效果）
        UIView.animate(withDuration: 1.2, delay: 0, options: .curveEaseOut, animations: {
            constraint.update(offset: offsetY)
            containerView.layoutIfNeeded()
        }) { [weak self] _ in
            guard let self = self, let pointsView = self.pointsView else { return }
            
            // ✅ 动画完成后更新波浪和气泡
            if targetView == pointsView.upblueView {
                self.bubbleAnimationManager.updateBlueViewAnimation(for: targetView, fillRatio: clampedRatio, animated: true)
            } else if targetView == pointsView.upinkView {
                self.bubbleAnimationManager.updatePinkViewAnimation(for: targetView, fillRatio: clampedRatio, animated: true)
            }
        }
        
        // ✅ 同时更新波浪（气泡只在动画完成后创建，避免重复）
        if targetView == pointsView.upblueView {
            bubbleAnimationManager.updateBlueViewAnimation(for: targetView, fillRatio: clampedRatio, animated: false)
        } else if targetView == pointsView.upinkView {
            bubbleAnimationManager.updatePinkViewAnimation(for: targetView, fillRatio: clampedRatio, animated: false)
        }
    }
    
    /// 应用蓝色视图的爱心填充
    func applyHeartMaskToBlueView(fillRatio: CGFloat, animated: Bool = true) {
        guard let pointsView = pointsView,
              pointsView.user1underheardView != nil,
              pointsView.upblueView != nil else { return }
        applyHeartMask(
            maskView: pointsView.user1underheardView,
            targetView: pointsView.upblueView,
            fillRatio: fillRatio,
            animated: animated
        )
    }
    
    /// 应用粉色视图的爱心填充
    func applyHeartMaskToPinkView(fillRatio: CGFloat, animated: Bool = true) {
        guard let pointsView = pointsView,
              pointsView.user2underheardView != nil,
              pointsView.upinkView != nil else { return }
        applyHeartMask(
            maskView: pointsView.user2underheardView,
            targetView: pointsView.upinkView,
            fillRatio: fillRatio,
            animated: animated
        )
    }
    
    /// 更新爱心填充（根据分数）
    /// - Parameters:
    ///   - myScore: 我的分数
    ///   - partnerScore: 伴侣的分数
    ///   - isEntryAnimation: 是否是进入动画
    ///   - emptyStateManager: 空状态管理器（用于更新空状态）
    func updateHeartFills(myScore: Int, partnerScore: Int, isEntryAnimation: Bool = false, emptyStateManager: PointsViewEmptyStateManager? = nil) {
        guard let pointsView = pointsView,
              pointsView.user1underheardView != nil,
              pointsView.user2underheardView != nil,
              pointsView.upblueView != nil,
              pointsView.upinkView != nil else {
            return
        }
        
        // ✅ 新的填充逻辑：基于两个分数的总和计算占比
        // 如果单个分数超过1万分，显示满爱心
        // 否则按占总和的比例显示
        // ✅ 如果分数是负数（扣分），不显示填充
        
        let totalScore = myScore + partnerScore
        let leftFillRatio: CGFloat
        let rightFillRatio: CGFloat
        
        if totalScore == 0 {
            // ✅ 两个分数都为0，都不显示
            leftFillRatio = 0.0
            rightFillRatio = 0.0
        } else {
            // ✅ 如果分数是负数（扣分），不显示填充
            if myScore < 0 {
                leftFillRatio = 0.0
            } else if myScore >= 10000 {
                // ✅ 如果单个分数超过1万分，显示满爱心
                leftFillRatio = 1.0
            } else {
                // ✅ 否则按占总和的比例显示
                leftFillRatio = CGFloat(myScore) / CGFloat(totalScore)
            }
            
            // ✅ 如果分数是负数（扣分），不显示填充
            if partnerScore < 0 {
                rightFillRatio = 0.0
            } else if partnerScore >= 10000 {
                // ✅ 如果单个分数超过1万分，显示满爱心
                rightFillRatio = 1.0
            } else {
                // ✅ 否则按占总和的比例显示
                rightFillRatio = CGFloat(partnerScore) / CGFloat(totalScore)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let pointsView = self.pointsView,
                  pointsView.isViewLoaded,
                  pointsView.user1underheardView != nil,
                  pointsView.user2underheardView != nil,
                  pointsView.upblueView != nil,
                  pointsView.upinkView != nil,
                  pointsView.upblueView?.bounds.width ?? 0 > 0,
                  pointsView.upinkView?.bounds.width ?? 0 > 0 else {
                return
            }
            
            // ✅ 检查是否需要更新空状态（两个分数都为0）
            let shouldUpdateEmptyState = (leftFillRatio == 0.0 && rightFillRatio == 0.0)
            
            if isEntryAnimation {
                self.applyHeartMaskToBlueView(fillRatio: 0, animated: false)
                self.applyHeartMaskToPinkView(fillRatio: 0, animated: false)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    self.applyHeartMaskToBlueView(fillRatio: leftFillRatio, animated: true)
                    self.applyHeartMaskToPinkView(fillRatio: rightFillRatio, animated: true)
                    
                    // ✅ 如果分数为0，在动画完成后更新空状态
                    if shouldUpdateEmptyState {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            emptyStateManager?.updateEmptyStatesWithCurrentData()
                        }
                    }
                }
            } else {
                self.applyHeartMaskToBlueView(fillRatio: leftFillRatio, animated: true)
                self.applyHeartMaskToPinkView(fillRatio: rightFillRatio, animated: true)
                
                // ✅ 如果分数为0，在动画完成后更新空状态
                if shouldUpdateEmptyState {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        emptyStateManager?.updateEmptyStatesWithCurrentData()
                    }
                }
            }
        }
    }
}

