//
//  BlueGradientView.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import SnapKit

class BlueGradientView: UIView {
    
    // Create the gradient layer as a property
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    // Override layoutSubviews to update the gradient frame
    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure the gradient layer's frame matches the view's bounds
        gradientLayer.frame = bounds
    }
    
    // A private method to configure the gradient
    private func setupGradient() {
        gradientLayer.colors = [
            UIColor.color(hexString: "#BCD9FF"),
            UIColor.color(hexString: "#B0E2FF")
        ]
        
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }
}
