//
//  KeyboardVisibleFlag.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

enum KeyboardVisibleFlag {
    static var isVisible: Bool = false

    private static let observer: Void = {
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
            isVisible = true
        }
        nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            isVisible = false
        }
        return ()
    }()

    /// 在 AppDelegate 启动时调用一次，开始监听键盘
    static func start() {
        _ = observer
    }
}
