//
//  WavesPopup.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import FFPopup
import ReactiveCocoa
import ReactiveSwift

class WavesPopup: NSObject, UIGestureRecognizerDelegate {
    private var popup: FFPopup!
    private var panStartPoint = CGPoint.zero
    private var panGestureRecognizer: UIPanGestureRecognizer?
    
    /// 是否在键盘弹出时自动偏移弹窗（默认 false，减轻第三方键盘卡顿）。FFPopup 本身无键盘适配，此属性便于与「禁用弹窗自动键盘偏移」方案一致，换库时可沿用。
    var autoAdjustPositionWhenKeyboardShows: Bool = false
    
    /// 点在输入框/文本区域时不让 pan 参与，触摸直接给 TextField/TextView，第一响应者立即生效，减轻键盘弹出卡顿
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else { return true }
        var v: UIView? = touch.view
        while let view = v {
            if view is UITextField || view is UITextView { return false }
            v = view.superview
        }
        return true
    }
    
    convenience init(contentView: UIView,
                     showType: FFPopup.ShowType,
                     dismissType: FFPopup.DismissType,
                     maskType: FFPopup.MaskType,
                     dismissOnBackgroundTouch: Bool,
                     dismissOnContentTouch: Bool,
                     dismissPanView: UIView? = nil) {
        self.init()
        popup = FFPopup(contentView: contentView,
                        showType: showType,
                        dismissType: dismissType,
                        maskType: maskType,
                        dismissOnBackgroundTouch: false,
                        dismissOnContentTouch: dismissOnContentTouch)
        
        // ✅ 禁用弹窗的自动键盘偏移（关键：减轻第三方键盘卡顿）
        autoAdjustPositionWhenKeyboardShows = false
        popup.backgroundView.isUserInteractionEnabled = true
        popup.dimmedMaskAlpha = 0.7
        
        // ✅ 背景点击关闭
        if dismissOnBackgroundTouch {
            let tap = UITapGestureRecognizer()
            tap.reactive.stateChanged.observeValues { [weak self] _ in
                self?.popup.dismiss(animated: true)
            }
            popup.backgroundView.addGestureRecognizer(tap)
        }
        
        // ✅ 区域下滑手势（默认整个 containerView，或自定义区域）
        let pan = UIPanGestureRecognizer()
        pan.reactive.stateChanged.observeValues { [weak self] pan in
            guard let self = self else { return }
            let view = self.popup.backgroundView
            let point = pan.location(in: view)
            
            switch pan.state {
            case .began:
                self.panStartPoint = point
                
            case .changed:
                var scale = (1 - point.y / view.bounds.height) /
                (1 - self.panStartPoint.y / view.bounds.height)
                scale = min(max(scale, 0), 1)
                self.popup.containerView.frame.origin.y =
                view.bounds.height - self.popup.containerView.bounds.height * scale
                
            case .cancelled, .failed:
                UIView.animate(withDuration: 0.15) {
                    self.popup.containerView.frame.origin.y =
                    view.bounds.height - self.popup.containerView.bounds.height
                }
                
            case .ended:
                if point.y - self.panStartPoint.y < 100 {
                    UIView.animate(withDuration: 0.15) {
                        self.popup.containerView.frame.origin.y =
                        view.bounds.height - self.popup.containerView.bounds.height
                    }
                } else {
                    self.popup.dismiss(animated: true)
                }
                
            default:
                break
            }
        }
        
        self.panGestureRecognizer = pan
        pan.delegate = self
        (dismissPanView ?? popup.containerView).addGestureRecognizer(pan)
    }
    
    func show(layout: FFPopupLayout) {
        popup.show(layout: layout)
    }
    
    func dismiss(animated: Bool) {
        popup.dismiss(animated: animated)
    }
    
    // 临时禁用手势识别器（用于动态更新弹窗高度时避免误触发）
    func setPanGestureEnabled(_ enabled: Bool) {
        panGestureRecognizer?.isEnabled = enabled
    }
    
    // 获取popup的containerView，用于动态更新高度
    var containerView: UIView? {
        return popup?.containerView
    }
}
