//
//  NBBasePopUpBox.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit



class NBBasePopUpBox: UIView {
    
    static private let shard = NBBasePopUpBox()
    var tapGesture: UITapGestureRecognizer?
    var originWindowWindowColor: UIColor?
    //    weak var popWindow: UIWindow?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        tapGesture = UITapGestureRecognizer(target: self, action:  #selector(hiddenPopup))
        self.addGestureRecognizer(tapGesture!)
    }
    
    func showActionSheet(){
        
        if let window = NBBasePopUpBox.getWindow(){
            //            popWindow = window
            self.frame = window.bounds
            originWindowWindowColor = window.backgroundColor
            //            popWindow?.backgroundColor = UIColor.black.alpha(0.5)
            window.addSubview(self)
        }
        //        popUpWindow.makeKeyAndVisible()
        //        popUpWindow.addSubview(self)
    }
    
    @objc func hiddenPopup(){
        //        let delegate = UIApplication.shared.delegate as! AppDelegate
        //        let window = delegate.window
        //        window?.makeKeyAndVisible()
        removeFromSuperview()
        if let window = NBBasePopUpBox.getWindow(){
            window.backgroundColor = originWindowWindowColor
        }
    }
    
    deinit {
#if DEBUG
        print("弹窗销毁")
#endif
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
     // Drawing code
     }
     */
    
    class func getWindow() -> UIWindow? {
        // 兼容 iOS 13.0 及以上版本
        if #available(iOS 13.0, *) {
            // 1. 遍历所有连接的 UIWindowScene
            let scenes = UIApplication.shared.connectedScenes
            for scene in scenes {
                // 2. 找到第一个处于活跃状态的 UIWindowScene
                guard let windowScene = scene as? UIWindowScene,
                      windowScene.activationState == .foregroundActive else {
                    continue
                }
                
                // 3. 遍历这个 scene 中的所有窗口
                for window in windowScene.windows {
                    // 4. 找到一个 windowLevel 为 .normal 并且 frame 匹配屏幕大小的窗口
                    if window.windowLevel == .normal && window.bounds.equalTo(UIScreen.main.bounds) {
                        return window
                    }
                }
            }
            
            // 如果没有找到，返回 nil
            return nil
        } else {
            // 兼容 iOS 13.0 以下版本，使用旧方法
            let windows = UIApplication.shared.windows
            for window in windows {
                if window.windowLevel == .normal && window.bounds.equalTo(UIScreen.main.bounds) {
                    return window
                }
            }
            return nil
        }
    }
}
