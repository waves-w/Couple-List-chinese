//
//  UIImageView+AvatarShadow.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import ObjectiveC

private var avatarShadowSecondLayerKey: UInt8 = 0

extension UIImageView {
    /// 第二层阴影用的 sublayer（与 userNameLabel1 一致：0.1 / (0,1) / 5）
    private var avatarShadowSecondLayer: CALayer? {
        get { objc_getAssociatedObject(self, &avatarShadowSecondLayerKey) as? CALayer }
        set { objc_setAssociatedObject(self, &avatarShadowSecondLayerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 为展示抠图头像的 imageView 应用双层阴影（与 userNameLabel 数值一致：一层 0.05+1，一层 0.1+5）
    func applyAvatarCutoutShadow() {
        clipsToBounds = false

        // 第一层：主 layer 的阴影（与 userNameLabel 一致：0.05 / (0,1) / 1）
        layer.shadowColor = UIColor.black.withAlphaComponent(0.05).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 1.0
        layer.shadowOpacity = 1.0

        // 第二层：专用 sublayer 的阴影（与 userNameLabel1 一致：0.1 / (0,1) / 5）
        let second: CALayer
        if let existing = avatarShadowSecondLayer, existing.superlayer == layer {
            second = existing
        } else {
            second = CALayer()
            second.name = "avatarShadowSecondLayer"
            second.masksToBounds = false
            layer.insertSublayer(second, at: 0)
            avatarShadowSecondLayer = second
        }
        second.name = "avatarShadowSecondLayer"
        second.frame = layer.bounds
        second.contents = image?.cgImage
        second.contentsGravity = contentMode == .scaleAspectFill ? .resizeAspectFill : .resizeAspect
        second.contentsScale = layer.contentsScale
        second.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        second.shadowOffset = CGSize(width: 0, height: 1)
        second.shadowRadius = 5.0
        second.shadowOpacity = 1.0
    }
}
