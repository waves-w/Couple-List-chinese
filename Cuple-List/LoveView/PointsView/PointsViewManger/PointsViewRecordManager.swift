//
//  PointsViewRecordManager.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import CoreData

class PointsViewRecordManager {
    
    // MARK: - 单例
    static let shared = PointsViewRecordManager()
    
    private init() {}
    
    // MARK: - 加载最近分数记录（只显示最后更新分数的两条，按 createTime 倒序）
    func loadRecentScoreRecords(
        isViewLoaded: Bool,
        completion: @escaping ([ScoreRecordModel], [ScoreRecordModel], [ScoreRecordModel]) -> Void
    ) {
        guard isViewLoaded else { return }
        
        ScoreManager.shared.getAllScoreRecords { [weak self] allRecords in
            guard let self = self else { return }
            
            if allRecords.isEmpty {
                ScoreManager.shared.getAllScoreRecords { cachedRecords in
                    PointsViewDataManager.generateTestRecordsFromCoreData(existingRecords: cachedRecords) { testRecords in
                        // ✅ 只取最后更新分数的两条（按 createTime 倒序，recordId 作为次要排序确保跨设备一致）
                        let recentRecords = Array(testRecords
                            .sorted { r1, r2 in
                                if r1.createTime != r2.createTime { return r1.createTime > r2.createTime }
                                return (r1.recordId ?? "") > (r2.recordId ?? "")
                            }
                            .prefix(2))
                        
                        DispatchQueue.main.async {
                            completion(recentRecords, testRecords, testRecords)
                        }
                    }
                }
                return
            }
            
            // ✅ 只取最后更新分数的两条（按 createTime 倒序，recordId 作为次要排序确保跨设备一致）
            let recentRecords = Array(allRecords
                .sorted { r1, r2 in
                    if r1.createTime != r2.createTime { return r1.createTime > r2.createTime }
                    return (r1.recordId ?? "") > (r2.recordId ?? "")
                }
                .prefix(2))
            
            DispatchQueue.main.async {
                completion(recentRecords, allRecords, allRecords)
            }
        }
    }
}

