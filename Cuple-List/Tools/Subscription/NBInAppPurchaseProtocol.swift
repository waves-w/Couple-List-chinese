//
//  NBInAppPurchaseProtocol.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import StoreKit
import RevenueCat


protocol NBInAppPurchaseProtocol {
     /**获取订阅商品成功*/
    func subscriptionProductsDidReciveSuccess(products: [StoreProduct])
    /**获取订阅商品失败*/
    func subscriptionProductsDidReciveFailure()
    /*
     * 订阅成功
     * needUnsubscribe  是否需要取消订阅
     */
    func purchasedSuccess(_ needUnsubscribe: Bool)
    /**订阅失败*/
	func purchasedFailure(error: Error?)
    /**恢复购买成功*/
    func restorePurchaseSuccess()
    /**恢复购买失败*/
    func restorePurchaseFailure()
    /*
     * 已经有购买回调
     * isOnetime   true 一次性购买， false 订阅
     */
    func haspurchased(_ isOnetime: Bool)

}


extension NBInAppPurchaseProtocol{
    /**获取订阅商品成功*/
    func subscriptionProductsDidReciveSuccess(products: [StoreProduct]){}
    /**获取订阅商品失败*/
    func subscriptionProductsDidReciveFailure(){}
     /*
      * 订阅成功
      * needUnsubscribe  是否需要取消订阅
      */
    func purchasedSuccess(_ needUnsubscribe: Bool){}
       /**订阅失败*/
    func purchasedFailure(){}
       /**恢复购买成功*/
    func restorePurchaseSuccess(){}
       /**恢复购买失败*/
    func restorePurchaseFailure(){}
    /*
     * 已经有购买回调
     * isOnetime   true 一次性购买， false 订阅
     */
    func haspurchased(_ isOnetime: Bool){}
}


extension NBInAppPurchaseProtocol where Self : UIViewController{
    //获取产品
    func requestProducts()  {
        NBNewStoreManager.shard.retrieveProductsInfo(true) { [weak self](isSuccess, aProducts) in
            if isSuccess{
                self?.subscriptionProductsDidReciveSuccess(products: aProducts)
            }else{
                self?.subscriptionProductsDidReciveFailure()
            }
        }
    }
	
    func purchase(product: StoreProduct, needUnsubscribe: Bool = true) {
        NBLoadingBox.startLoadingAnimation()
        NBNewStoreManager.shard.purchaseProductAndCheckSubscriptions(product) { [weak self](purchaseStatus, purchaseState) in
			DispatchQueue.main.async {
				NBLoadingBox.stopLoadAnimation()
			}
            switch purchaseStatus{
            case .purchaseSuccess:
				self?.purchasedSuccess(needUnsubscribe)
            case .purchaseFailure(let error):
				self?.purchasedFailure(error: error)
            case .purchaseCancelled:
                break
            }
        }
    }
    
    
    func restorePurchaseData(){
        NBLoadingBox.startLoadingAnimation()
        NBNewStoreManager.shard.restoreAndCheckSubscriptions { [weak self](restoreStatus, purchaseState) in
            NBLoadingBox.stopLoadAnimation()
            switch restoreStatus{
            case .noPurchase:
                 self?.restorePurchaseFailure()
            case .restoreFailed:
                 self?.restorePurchaseFailure()
            case .restoreSuccess:
                if let purchaseState = purchaseState{
					if purchaseState.haveSubscription{  //有订阅
						 self?.restorePurchaseSuccess()
					}else{
						 self?.restorePurchaseFailure()
					}
                }
            }
        }
    }
}
