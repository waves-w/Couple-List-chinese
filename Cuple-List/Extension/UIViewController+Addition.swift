//
//  UIViewController+Addition.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation
import UIKit
import MediaPlayer


public extension UIViewController {
    func getWindow() -> UIWindow {
        if view.window != nil {
            return view.window!
        } else {
            return UIApplication.shared.connectedScenes
                .filter({$0.activationState == .foregroundActive})
                .map({$0 as? UIWindowScene})
                .compactMap({$0})
                .first?.windows
                .filter({$0.isKeyWindow}).first ?? UIWindow()
        }
    }
    
    
	func statusBarHeight() -> CGFloat {
		return getWindow().windowScene?.statusBarManager?.statusBarFrame.size.height ?? 0
	}
	
	
	func navigationBarHeight() -> CGFloat {
		return navigationController?.navigationBar.isHidden ?? true ? 0 : navigationController!.navigationBar.height()
	}
	
	
	func topSpacing() -> CGFloat {
		return statusBarHeight() + navigationBarHeight()
	}
	
	
	func bottomSafeAreaPadding() -> CGFloat {
		return view.safeAreaInsets.bottom
	}
	
	
	func tabBarHeight() -> CGFloat {
//        if let tabBarController = tabBarController as? MomoTabBarController {
//            return tabBarController.simulationTabBar.isHidden ? 0 : tabBarController.simulationTabBar.height()
//        }
        return 0
	}
	
	
	func bottomSpacing() -> CGFloat {
		if tabBarHeight() > 0 {
			return tabBarHeight()
		} else {
			return bottomSafeAreaPadding()
		}
	}
	
	
	class func getCurrentViewController(base: UIViewController?) -> UIViewController? {
		var base = base
		if base == nil {
			let keyWindow = UIApplication.shared.connectedScenes
					.filter({$0.activationState == .foregroundActive})
					.map({$0 as? UIWindowScene})
					.compactMap({$0})
					.first?.windows
					.filter({$0.isKeyWindow}).first
			base = keyWindow?.rootViewController
		}
		
		if let nav = base as? UINavigationController {
			return getCurrentViewController(base: nav.visibleViewController)
		}
		if let tab = base as? UITabBarController {
			return getCurrentViewController(base: tab.selectedViewController)
		}
		if let presented = base?.presentedViewController {
			return getCurrentViewController(base: presented)
		}
		return base
	}
    
    
//    func showSubscriptionIfNeeded(handler: (() -> Void)?) {
//        if NBUserVipStatusManager.shard.getVipStatus() {
//            if let handler = handler {
//                handler()
//            }
//        } else {
//            let vc = VipViewController()
//            vc.handler = handler
//            vc.modalPresentationStyle = .fullScreen
//            present(vc, animated: true, completion: nil)
//        }
//    }
    
    
    func setVolume() {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
            slider?.value = 1
        }
    }
}
