//
//  UIView+Addition.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation
import UIKit


public extension UIView {
	func width() -> CGFloat {
		return bounds.size.width
	}
	
	func height() -> CGFloat {
		return bounds.size.height
	}
	
	func halfWidth() -> CGFloat {
		return width() / 2
	}
	
	func halfHeight() -> CGFloat {
		return height() / 2
	}
	
	func centerX() -> CGFloat {
		return center.x
	}
	
	func centerY() -> CGFloat {
		return center.y
	}
	
	func minX() -> CGFloat {
		return frame.origin.x
	}
	
	func minY() -> CGFloat {
		return frame.origin.y
	}
	
	func maxX() -> CGFloat {
		return minX() + width()
	}
	
	func maxY() -> CGFloat {
		return minY() + height()
	}
	
	func layoutNow() {
		setNeedsLayout()
		layoutIfNeeded()
	}
	
	func setShadow(color: UIColor = .color(hexString: "#14252275"), offset: CGSize = CGSize(width: 0, height: 12), radius: CGFloat = 30, opacity: Float = 1) {
		layer.shadowColor = color.cgColor
		layer.shadowOffset = offset
		layer.shadowRadius = radius
		layer.shadowOpacity = opacity
	}
	
	func shake() {
		let viewLayer = layer
		let position = viewLayer.position
		let x = CGPoint(x: position.x + 10, y: position.y)
		let y = CGPoint(x: position.x - 10, y: position.y)
		let animation = CABasicAnimation(keyPath: "position")
		animation.timingFunction = CAMediaTimingFunction(name: .default)
		animation.fromValue = x
		animation.toValue = y
		animation.autoreverses = true
		animation.duration = 0.06
		animation.repeatCount = 3
		viewLayer.add(animation, forKey: nil)
	}
    
    
    func asImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0)
        drawHierarchy(in: bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    
    func setOrigin(x: CGFloat, y: CGFloat) {
        center = CGPoint(x: x + halfWidth(), y: y + halfHeight())
    }
	
	
	func getWindow() -> UIWindow? {
		if window != nil {
			return window
		} else {
			return UIApplication.shared.connectedScenes
				.filter({$0.activationState == .foregroundActive})
				.map({$0 as? UIWindowScene})
				.compactMap({$0})
				.first?.windows
				.filter({$0.isKeyWindow}).first
		}
	}
}
