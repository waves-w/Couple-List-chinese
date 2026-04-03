//
//  PointsViewEmptyStateManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import CoreData

class PointsViewEmptyStateManager {
    
    weak var pointsView: PointsView?
    
    init(pointsView: PointsView) {
        self.pointsView = pointsView
    }
    
    // MARK: - 更新空状态显示
    func updateEmptyStates(hasRecordData: Bool, hasWishData: Bool) {
        guard let view = pointsView,
              view.isViewLoaded,
              view.view.window != nil,
              let allEmptyImageView = view.allEmptyImageView,
              let recordsEmptyImageView = view.recordsEmptyImageView,
              let wishListEmptyImageView = view.wishListEmptyImageView,
              let breakButton = view.breakButton,
              let wishLabel = view.wishLabel,
              let userPointsView = view.userPointsView else {
            return
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if !hasRecordData && !hasWishData {
            allEmptyImageView.isHidden = false
            recordsEmptyImageView.isHidden = true
            wishListEmptyImageView.isHidden = true
            wishLabel.isHidden = true
            breakButton.isHidden = true
            userPointsView.isHidden = true
            if view.wishtableView.isViewLoaded {
                view.wishtableView.view.isHidden = true
            }
            CATransaction.commit()
            return
        }
        
        allEmptyImageView.isHidden = true
        breakButton.isHidden = !hasRecordData
        userPointsView.isHidden = !hasRecordData
        recordsEmptyImageView.isHidden = hasRecordData
        wishListEmptyImageView.isHidden = hasWishData
        if view.wishtableView.isViewLoaded {
            view.wishtableView.view.isHidden = !hasWishData
        }
        wishLabel.isHidden = false
        
        CATransaction.commit()
    }
    
    // MARK: - 使用当前实际数据更新空状态
    func updateEmptyStatesWithCurrentData() {
        guard let view = pointsView else { return }
        let hasRecordData = !view.record1View.isHidden || !view.record2View.isHidden
        let hasWishData = view.wishtableView.isViewLoaded &&
        (view.wishtableView.fetchedResultsController?.fetchedObjects?.count ?? 0) > 0
        updateEmptyStates(hasRecordData: hasRecordData, hasWishData: hasWishData)
    }
}

