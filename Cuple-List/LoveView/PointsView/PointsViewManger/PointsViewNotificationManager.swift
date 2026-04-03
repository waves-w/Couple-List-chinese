//
//  PointsViewNotificationManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

class PointsViewNotificationManager {
    
    // MARK: - Properties
    
    weak var pointsView: PointsView?
    
    // MARK: - Initialization
    
    init(pointsView: PointsView) {
        self.pointsView = pointsView
    }
    
    // MARK: - Public Methods
    
    /// 注册所有通知监听
    func registerNotifications() {
        NotificationCenter.default.addObserver(
            pointsView!,
            selector: #selector(PointsView.refreshScoreWhenChanged),
            name: ScoreDidUpdateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            pointsView!,
            selector: #selector(PointsView.avatarDidUpdate),
            name: UserManger.avatarDidUpdateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            pointsView!,
            selector: #selector(PointsView.wishDataDidUpdate),
            name: PointsManger.dataDidUpdateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            pointsView!,
            selector: #selector(PointsView.wishListDataDidChange),
            name: NSNotification.Name("WishListDataDidChange"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            pointsView!,
            selector: #selector(PointsView.handleCoupleDidUnlink),
            name: CoupleStatusManager.coupleDidUnlinkNotification,
            object: nil
        )
    }
    
    /// 移除所有通知监听
    func removeNotifications() {
        NotificationCenter.default.removeObserver(pointsView!)
    }
}






