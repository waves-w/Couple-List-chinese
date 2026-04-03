//
//  UILabel+Addition.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation
import UIKit


public extension String {
        static func randomNumeric(length: Int) -> String {
            return (0..<length).map { _ in String(Int.random(in: 0...9)) }.joined()
        }
    }
