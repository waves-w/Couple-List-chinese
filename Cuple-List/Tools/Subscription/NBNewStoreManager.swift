//
//  NBNewStoreManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import StoreKit
import RevenueCat
import DeviceKit


extension StoreProduct{
    var regularPrice: String {
        return localizedPriceString
    }
    
    var freeDays: Int {
        var freedays = 0
        if let periods = introductoryDiscount?.numberOfPeriods, let units = introductoryDiscount?.subscriptionPeriod.value {
            switch introductoryDiscount?.subscriptionPeriod.unit {
            case .day:
                freedays = periods * units
            case .week:
                freedays = periods * units * 7
            case .month:
                freedays = periods * units * 30
            case .year:
                freedays = periods * units * 365
            default:
                break
            }
        }
        return freedays
    }
}

struct NBPurchaseState {
    var cheackSuccess: Bool
    var haveSubscription: Bool
    var deadLine: Date?
}



class NBNewStoreManager: NSObject,SKPaymentTransactionObserver{

    //购买状态
    enum NBPurchaseStatus {
		case purchaseFailure(Error?)        //购买失败
        case purchaseCancelled       //支付取消
        case purchaseSuccess
    }
    
    enum NBRestoreStatus{
        case noPurchase         //未购买
        case restoreSuccess     //恢复成功
        case restoreFailed      //恢复失败
    }

    let weekProductId = "com.menghan.couplelist.weekly"
    let monthProductId = "com.Couple.Monthly"
    let yearProductId = "com.menghan.couplelist.yearly"
    let sharedSecret = "c4d59d546e494b23b8d61fa5ae1f15f6"
    
    private var products: [StoreProduct]?

    
    static let shard = NBNewStoreManager()
    
    @objc open class func shardInstance() -> NBNewStoreManager{
        return shard
    }
    
    
    func allProuductIds() -> [String] {
        return [weekProductId, monthProductId, yearProductId]
    }
    
    /**获取所有产品信息*/
    func retrieveProductsInfo(_ needReload:Bool = false,_ callBack:@escaping ((_ isSuccess: Bool,_ products: [StoreProduct])->())) {
        // ✅ 检查 RevenueCat 是否已配置
        guard Purchases.isConfigured else {
            print("❌ RevenueCat 未初始化，无法获取产品")
            callBack(false, [StoreProduct]())
            return
        }
        
        print("🔍 RevenueCat: 开始获取产品信息...")
        print("   - RevenueCat 已配置: \(Purchases.isConfigured)")
        print("   - App User ID: \(Purchases.shared.appUserID)")
        
        if needReload{
            products = nil
        }
        if let products = products{
            print("✅ RevenueCat: 使用缓存的产品（\(products.count) 个）")
            callBack(true,products)
            return
        }
        
        Purchases.shared.getOfferings {
			offerings, error in
			print("🔍 RevenueCat: getOfferings 回调")
			print("   - Offerings: \(offerings != nil ? "存在" : "nil")")
			print("   - Error: \(error?.localizedDescription ?? "nil")")
			
			if let offerings = offerings {
				print("   - 所有 Offerings: \(offerings.all.keys.joined(separator: ", "))")
			}
			
			// 需在 RevenueCat Dashboard 创建 identifier 为 "default" 的 Offering 并关联产品，见 docs/RevenueCat-配置说明.md
			if let offering = offerings?.all["default"] {
				let products = offering.availablePackages.map {
					package in
                    return package.storeProduct
				}
				print("✅ RevenueCat: 成功获取 \(products.count) 个产品")
				for product in products {
					print("   - 产品 ID: \(product.productIdentifier)")
				}
				self.products = products
				callBack(true, products)
				return
			}
			
			// ✅ 详细错误分析
			if let error = error {
				print("❌ RevenueCat 获取产品失败: \(error.localizedDescription)")
				// ✅ 检查错误代码，提供更详细的提示
				if let nsError = error as NSError? {
					print("   错误域: \(nsError.domain), 错误代码: \(nsError.code)")
					// 尝试将错误代码转换为 ErrorCode
					if let errorCode = ErrorCode(rawValue: nsError.code) {
						print("   RevenueCat 错误代码: \(errorCode)")
						switch errorCode {
						case .invalidCredentialsError:
							print("⚠️ RevenueCat API Key 可能无效，请检查 AppDelegate 中的配置")
							print("   当前 API Key: appl_cNRSoyBfjDSEYSqhxwEnbghogIn")
						case .networkError:
							print("⚠️ 网络连接问题，请检查网络设置")
						case .configurationError:
							print("⚠️ RevenueCat 配置错误，请检查 Dashboard 中的设置")
						default:
							print("⚠️ 其他错误: \(errorCode)")
						}
					} else {
						print("⚠️ 无法识别的错误代码: \(nsError.code)")
					}
				}
			} else {
				// ✅ 没有错误，但没有找到 default offering
				print("⚠️ RevenueCat: 未找到 'default' offering")
				if let offerings = offerings {
					print("   可用的 Offerings: \(offerings.all.keys.joined(separator: ", "))")
					print("   ⚠️ 请确保在 RevenueCat Dashboard 中创建名为 'default' 的 Offering")
				} else {
					print("   ⚠️ Offerings 为 nil，可能是配置问题")
				}
			}
			callBack(false, [StoreProduct]())
		}
    }
    
    /// 检查 CustomerInfo 是否有有效的订阅权益
    /// - Note: Dashboard 若未把产品挂到 Entitlement，`entitlements.active` 可能仍为空，但 `activeSubscriptions` 会有产品 ID（与日志「已购买但 entitlement 未激活」一致）
    private func hasActiveEntitlement(_ info: CustomerInfo?, purchasedProductId: String? = nil) -> Bool {
        guard let info = info else { return false }
        if info.entitlements.all["all"]?.isActive == true { return true }
        if !info.entitlements.active.isEmpty { return true }
        if let pid = purchasedProductId, info.activeSubscriptions.contains(pid) { return true }
        if !info.activeSubscriptions.isEmpty { return true }
        return false
    }
    
    /**购买*/
    func purchaseProduct(_ product: StoreProduct, callBack:@escaping ((_ status: NBPurchaseStatus)->())) {
        Purchases.shared.purchase(product: product) { [weak self]
			transaction, purchaserInfo, error, userCancelled in
			if userCancelled {
				callBack(.purchaseCancelled)
				return
			}
            // 优先用回调里的 purchaserInfo 判断（传入 productId，避免仅 entitlement 未配置时误判失败）
            if self?.hasActiveEntitlement(purchaserInfo, purchasedProductId: product.productIdentifier) == true {
                callBack(.purchaseSuccess)
                return
            }
            // 无 error 但 entitlement 未就绪：可能是缓存延迟，或 transaction 在 purchasesAreCompletedBy == .myApp 时为 nil（见 RevenueCat 文档）
            // 不依赖 transaction，只要未取消且无 error 就 sync + 拉取最新 CustomerInfo 再判一次
            if error == nil {
                Task {
                    let productId = product.productIdentifier
                    Purchases.shared.invalidateCustomerInfoCache()
                    try? await Purchases.shared.syncPurchases()
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    var freshInfo = try? await Purchases.shared.customerInfo()
                    if self?.hasActiveEntitlement(freshInfo, purchasedProductId: productId) != true {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        Purchases.shared.invalidateCustomerInfoCache()
                        try? await Purchases.shared.syncPurchases()
                        freshInfo = try? await Purchases.shared.customerInfo()
                    }
                    await MainActor.run {
                        if self?.hasActiveEntitlement(freshInfo, purchasedProductId: productId) == true {
                            callBack(.purchaseSuccess)
                        } else {
                            print("⚠️ RevenueCat: 购买后 entitlement 未激活。请在 Dashboard 检查：1) Entitlement 标识是否为「all」；2) 订阅产品是否已关联到该 Entitlement；3) Offering「default」是否包含这些产品")
                            callBack(.purchaseFailure(error))
                        }
                    }
                }
                return
            }
			callBack(.purchaseFailure(error))
		}
    }
    
    /**恢复购买*/
    func restorePurchases(_ callBack:@escaping ((_ restoreStatus: NBRestoreStatus)->())) {
        Purchases.shared.restorePurchases { [weak self] purchaserInfo, error in
			if error != nil {
				callBack(.restoreFailed)
				return
			}
			if self?.hasActiveEntitlement(purchaserInfo) == true {
				callBack(.restoreSuccess)
			} else {
				callBack(.restoreFailed)
			}
		}
    }
	
    /**检查订阅状态*/
    func checkPurchaseStatus(_ callBack:@escaping ((_ purchaseState: NBPurchaseState)->())) {
        Task {
            let checkSuccess = false
            //是否有买断状态
            var haveOnetimePurchase: Bool = false
            //是否有订阅
            var haveSubscription: Bool = false
            //订阅到期时间
            var deadLine: Date?
            do {
                let user = try await Purchases.shared.customerInfo()
                // informational 模式下 verification 常为 notRequested，不能仅判断 verified
                let canTrustEntitlements = user.entitlements.verification != .failed
                if canTrustEntitlements {
                    if let info = user.entitlements.all["all"], info.isActive {
                        haveSubscription = true
                        haveOnetimePurchase = false
                        deadLine = info.expirationDate
                        UserDefaults.standard.set(info.productIdentifier, forKey: UserDefaultsKey.SubscriptionId)
                    } else {
                        // 产品与 Entitlement 未关联时，activeSubscriptions 仍有数据
                        let ids = self.allProuductIds()
                        if let pid = user.activeSubscriptions.first(where: { ids.contains($0) }) {
                            haveSubscription = true
                            deadLine = user.expirationDate(forProductIdentifier: pid)
                            UserDefaults.standard.set(pid, forKey: UserDefaultsKey.SubscriptionId)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
            let purchaseState = NBPurchaseState(cheackSuccess: checkSuccess, haveSubscription: haveSubscription, deadLine: deadLine)
            if haveOnetimePurchase { //有一次性买断
                NBUserVipStatusManager.shard.recordOnetimePurchase()
                callBack(purchaseState)
            } else if haveSubscription {  //有订阅
                NBUserVipStatusManager.shard.recordSubscriptionStatus(deadLine)
                callBack(purchaseState)
            } else {
                NBUserVipStatusManager.shard.recordSubscriptionStatus(nil)
                callBack(purchaseState)
            }
        }
    }
    
    //MARK:--SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // 购买成功：进行服务器收据验证
                // ... 验证完成后 ...
                queue.finishTransaction(transaction) // ⚠️ 必须调用
                
            case .failed:
                // 购买失败：显示错误信息
                // ...
                queue.finishTransaction(transaction) // ⚠️ 必须调用
                
            case .restored:
                // 恢复购买：更新状态
                // ...
                queue.finishTransaction(transaction) // ⚠️ 必须调用
                
            case .deferred, .purchasing:
                // 延迟或正在购买：什么都不做，等待下一个状态更新
                break
                
            @unknown default:
                // 遇到未知状态，通常也应完成事务以防卡住
                queue.finishTransaction(transaction)
            }
        }
    }
    
    func paymentQueueDidChangeStorefront(_ queue: SKPaymentQueue) {
		NotificationCenter.default.post(name: .NBAppStoreDidChange, object: nil)
	}
}


extension NBNewStoreManager{
    /**
        * 支付并更新订阅状态
        * purchaseStatus   支付状态
        * purchaseState  用于票据状态
        */
	func purchaseProductAndCheckSubscriptions(_ product: StoreProduct,_ callBack:@escaping  ((_ purchaseStatus: NBPurchaseStatus,_ purchaseState: NBPurchaseState?)->())) {
		purchaseProduct(product) { [weak self] (purchaseStatus) in
			switch purchaseStatus {
			case .purchaseSuccess:
				self?.checkPurchaseStatus {
					(purchaseState) in
					if purchaseState.haveSubscription {
						if let deadLine = purchaseState.deadLine {
							NBUserVipStatusManager.shard.recordSubscriptionStatus(deadLine)
						} else {
							NBUserVipStatusManager.shard.recordOnetimePurchase()
						}
					}
					callBack(purchaseStatus, purchaseState)
				}
			default:
				callBack(purchaseStatus, nil)
			}
		}
	}
       
       /**
        *      isHavePurchases 是否有购买订单
        *      isRestoreSuccess  是否恢复成功
        *      purchaseState  用于票据状态
        */
    func restoreAndCheckSubscriptions(_ callBack:@escaping  ((_ restoreStatus: NBRestoreStatus, _ purchaseState: NBPurchaseState?)->())){
        restorePurchases {
            [weak self] (aRestoreStatus) in
            switch aRestoreStatus{
            case .restoreSuccess:
                self?.checkPurchaseStatus {
                    (purchaseState) in
                    if purchaseState.haveSubscription {
						if let deadLine = purchaseState.deadLine {
							NBUserVipStatusManager.shard.recordSubscriptionStatus(deadLine)
						} else {
							NBUserVipStatusManager.shard.recordOnetimePurchase()
						}
                    }
                    callBack(aRestoreStatus, purchaseState)
                }
            case .restoreFailed,.noPurchase:
                callBack(aRestoreStatus, nil)
            }
        }
    }
}






extension NBNewStoreManager{
    
    //获取免费天
    static func getFreeDays(_ product:SKProduct) -> Int{
        var freeDays = 0
        if #available(iOS 11.2, *) {
            if let periods =  product.introductoryPrice?.numberOfPeriods, let units = product.introductoryPrice?.subscriptionPeriod.numberOfUnits  {
                switch product.introductoryPrice?.subscriptionPeriod.unit {
                case .day:
                    freeDays = periods * units
                case .week:
                    freeDays = periods * units * 7
                case .month:
                    freeDays = periods * units * 30
                case .year:
                    freeDays = periods * units * 365
                default:
                    break
                }
            }
        }
        return freeDays
    }
    
    //获取国际化价格
    static func getLocationPrice(_ product:SKProduct) -> NSDecimalNumber{
        let originPrice = product.price
        return originPrice
    }
    static func getCycles(_ product:SKProduct) -> String{
           var cycles = ""
           if #available(iOS 11.2, *) {
               switch product.subscriptionPeriod?.unit {
               case .day:
                   cycles = "day"
               case .week:
                   cycles = "week"
               case .month:
                   cycles = "month"
               case .year:
                   cycles = "year"
               default:
                   break
               }
           } else {
               cycles = product.productIdentifier
               // Fallback on earlier versions
           }
           return cycles
       }
       
       static func getSymbol(_ product:SKProduct) -> String {
           return product.priceLocale.currencySymbol ?? ""
       }
    
       static func getProductInfo(_ product: SKProduct) -> String{
           let cycles = getCycles(product)
           let freeDays = getFreeDays(product)
           let price = getLocationPrice(product)
           let symbol = getSymbol(product)
           let productInfo = String(format: "%@ %@%@%.2f", cycles, (freeDays == 0) ?"" :"\(freeDays)days free + ", symbol,price.doubleValue)
           return productInfo
       }
}


extension Notification.Name{
    //商店发生变化通知
    static let  NBAppStoreDidChange = Notification.Name.init("NBAppStoreDidChange")
    static let  NBAppPurchasedStatusDidChange = Notification.Name.init("NBAppPurchasedStatusDidChange")
    
//    static let
}
