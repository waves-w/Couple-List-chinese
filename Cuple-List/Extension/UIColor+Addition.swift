//
//  UIColor+Addition.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation
import UIKit


public extension UIColor {
	class func color(hexString: String) -> UIColor {
		if !hexString.hasPrefix("#") || !(hexString.count == 7 || hexString.count == 9) {
			assert(false, "色值字符串错误：\(hexString)")
		}
		
		func getHex(range: Range<String.Index>) -> CGFloat {
			let subString = hexString[range]
			let hexValue = CGFloat(strtoul(String(subString), nil, 16)) / 255.0
			return hexValue
		}
		
		let alpha 	= hexString.count == 7 ? 1 : getHex(range: hexString.index(hexString.startIndex, offsetBy: 1)..<hexString.index(hexString.startIndex, offsetBy: 3))
		let blue 	= getHex(range: hexString.index(hexString.endIndex, offsetBy: -2)..<hexString.endIndex)
		let green	= getHex(range: hexString.index(hexString.endIndex, offsetBy: -4)..<hexString.index(hexString.endIndex, offsetBy: -2))
		let red		= getHex(range: hexString.index(hexString.endIndex, offsetBy: -6)..<hexString.index(hexString.endIndex, offsetBy: -4))
		return UIColor(red: red, green: green, blue: blue, alpha: alpha)
	}
    
    
    class func mixColor(color1: UIColor, color2: UIColor, ratio: CGFloat) -> UIColor {
        guard let components1 = color1.cgColor.components else { return color1 }
        guard let components2 = color2.cgColor.components else { return color1 }
        let r = components2[0] * ratio + components1[0] * (1 - ratio)
        let g = components2[1] * ratio + components1[1] * (1 - ratio)
        let b = components2[2] * ratio + components1[2] * (1 - ratio)
        let a = components2[3] * ratio + components1[3] * (1 - ratio)
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
