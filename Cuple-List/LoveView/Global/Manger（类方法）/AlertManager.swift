//
//  AlertManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

/// 弹窗工具类：统一管理提示弹窗（适配 View/ViewController 传入）
class AlertManager: NSObject {
    /// 显示单按钮弹窗（仅提示）
    /// - Parameters:
    ///   - message: 弹窗提示文本
    ///   - target: 弹窗依附的目标（可传 UIViewController 或 UIView，自动获取对应控制器）
    static func showSingleButtonAlert(message: String, target: AnyObject? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Hint", message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default)
            alert.addAction(action)
            
            // ✅ 必须用 keyWindow，否则多窗口/弹窗时可能 present 到错误窗口，导致关掉弹窗后后续跳转全失效
            guard let keyWindow = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow }) else {
                return
            }
            guard let topVC = AlertManager.topViewController(from: keyWindow.rootViewController) else {
                return
            }
            
            // 避免重复弹窗（当前顶层已是 Alert 则跳过）
            if topVC is UIAlertController {
                return
            }
            
            // ✅ 在用户当前看到的「顶层 VC」上 present，关掉弹窗后导航栈/响应链保持正常，后续跳转不会失效
            topVC.present(alert, animated: true)
        }
    }
    
    /// 从某 VC 起递归得到当前展示的顶层 VC（含 presented）
    private static func topViewController(from base: UIViewController?) -> UIViewController? {
        guard var vc = base else { return nil }
        while let presented = vc.presentedViewController {
            vc = presented
        }
        return vc
    }
    
    /// 从目标（View/ViewController）中获取控制器
    private static func getViewController(from target: AnyObject?) -> UIViewController? {
        guard let target = target else { return nil }
        
        // 若目标是控制器，直接返回
        if let targetVC = target as? UIViewController {
            return targetVC
        }
        
        // 若目标是视图，查找其所在的控制器
        if let targetView = target as? UIView {
            var responder: UIResponder? = targetView
            while responder != nil {
                if let vc = responder as? UIViewController {
                    return vc
                }
                responder = responder?.next
            }
        }
        
        return nil
    }
    
    /// 获取当前顶层控制器（适配导航栏/标签栏）
    private static func topViewController() -> UIViewController? {
        var window = UIApplication.shared.windows.first { $0.isKeyWindow }
        if #available(iOS 13.0, *) {
            window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        }
        guard var topVC = window?.rootViewController else { return nil }
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        return topVC
    }
}
