//
//  Bundle+Addition.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation


extension Bundle {
    func isSandbox() -> Bool {
        if let url = appStoreReceiptURL {
            let path = url.path
            return path.contains("sandboxReceipt")
        }
        return false
    }
}
