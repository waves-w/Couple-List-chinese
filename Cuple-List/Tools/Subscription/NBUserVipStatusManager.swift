//
//  NBUserVipStatusManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import RevenueCat


class NBUserVipStatusManager: NSObject {

    static let shard = NBUserVipStatusManager()
    var isVip: Bool!{
        get {
            return getVipStatus()
        }
    }
    //订阅状态的过期时间
    private let NBSubscriptionExpiresDate = "NBSubscriptionExpiresDate"
    //最后一次检查订阅状态的日期  用系统时间记录
    private let NBLastCheackVipStatusDate = "NBLastCheackVipStatusDate"
    //订阅状态
    private let NBSubscriptionStatus = "NBSubscriptionStatus"
    
    //记录订阅可用时间
    private let NBCanUserMinute = "NBCanUserMinute"
    
    private let NBCanUserHour = "NBCanUserHour"
    
    //否有一次性购买
    private let NBOneTimePurchases = "NBOneTimePurchases"
    
    //记录订阅状态回调
    private var recordSubscriptionBlock: ((_ isSuccess: Bool)->())?
    
    
    @objc open class func shardInstance() -> NBUserVipStatusManager{
        return shard
    }
    
    private override init() {
        super.init()
    }
    
    @objc func getVipStatus() -> Bool{
		#if DEBUG
		return true
		#else
            //测试模式下的订阅状态
//        if Bundle.main.isSandbox() {
//            return true
//        }
        var isAvailable = false
        if UserDefaults.standard.bool(forKey: UserDefaultsKey.OneTimePurchases){
            isAvailable = true
        } else {
            if let expiresDate = UserDefaults.standard.object(forKey: UserDefaultsKey.SubscriptionExpiresDate) as? Date{
                if Date() < expiresDate{
                   isAvailable = true
                }
            }
        }
        return isAvailable
		#endif
    }
    
    /// 与 Release 下权益判定一致，不因 `#if DEBUG` 恒为 true；用于订阅过期后的功能拦截、本地调试付费墙
    func isSubscriptionActiveForFeatureGating() -> Bool {
        if UserDefaults.standard.bool(forKey: UserDefaultsKey.OneTimePurchases) { return true }
        if let expiresDate = UserDefaults.standard.object(forKey: UserDefaultsKey.SubscriptionExpiresDate) as? Date,
           Date() < expiresDate {
            return true
        }
        return false
    }
    
   
    /** 记录一次性购买状态*/
    func recordOnetimePurchase() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.OneTimePurchases)
        NotificationCenter.default.post(name: .NBUserSubscriptionStatusDidChange, object: nil)
    }
    /**记录订阅状态*/
    func recordSubscriptionStatus(_ expiresDate: Date?) {
        UserDefaults.standard.set(expiresDate, forKey: UserDefaultsKey.SubscriptionExpiresDate)
        if expiresDate == nil && UserDefaults.standard.bool(forKey: UserDefaultsKey.OneTimePurchases) {
            UserDefaults.standard.set(false, forKey: UserDefaultsKey.OneTimePurchases)
            NotificationCenter.default.post(name: .NBUserSubscriptionStatusDidChange, object: nil)
        }
    }
}


extension Notification.Name{
    static let NBUserSubscriptionStatusDidChange = Notification.Name.init("NBUserSubscriptionStatusDidChange")
}


extension UserDefaultsKey {
    static let OneTimePurchases = "OneTimePurchasesUserDefaultsKeyForPublic"
    static let SubscriptionExpiresDate = "SubscriptionExpiresDateUserDefaultsKeyForPublic"
    static let SubscriptionId = "SubscriptionIdUserDefaultsKeyForPublic"
    static let OriginPurchaseDate = "OriginPurchaseDateUserDefaultsKeyForPublic"
    static let LatestExpirationDate = "LatestExpirationDateUserDefaultsKeyForPublic"
}

// MARK: - 非订阅时弹出续费页（与设置里 `getVipStatus()` 展示可能不一致：Debug 下设置仍视为 VIP，拦截以「真实到期」为准）

enum SubscriptionPaywallGate {
    static var isSubscriptionActive: Bool {
        NBUserVipStatusManager.shard.isSubscriptionActiveForFeatureGating()
    }
    
    static func presentPaywall(from presenter: UIViewController, animated: Bool = true) {
        let vc = VipUIViewController()
        vc.modalPresentationStyle = .fullScreen
        presenter.present(vc, animated: animated)
    }
    
    /// 未订阅时弹订阅页并返回 `false`；已订阅返回 `true`
    @discardableResult
    static func requireSubscription(from presenter: UIViewController?) -> Bool {
        guard !isSubscriptionActive else { return true }
        if let p = presenter ?? UIViewController.getCurrentViewController(base: nil) {
            presentPaywall(from: p)
        }
        return false
    }
}

