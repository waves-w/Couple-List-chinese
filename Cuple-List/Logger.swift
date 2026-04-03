//
//  Logger.swift
//  Cuple-List
//
//  Created by wanghaojun.
//

import Foundation


class Logger {
    class func testLog(_ content: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd HH:mm:ss SSS"
        print(dateFormatter.string(from: Date()) + content)
    }
}
