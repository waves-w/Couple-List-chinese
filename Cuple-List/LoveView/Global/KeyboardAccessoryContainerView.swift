//
//  KeyboardAccessoryContainerView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

/// 高度固定的容器视图，用作 UITextField.inputAccessoryView 时系统能正确布局显示（避免高度被压成 0）。
final class KeyboardAccessoryContainerView: UIView {

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 60)
    }
}
