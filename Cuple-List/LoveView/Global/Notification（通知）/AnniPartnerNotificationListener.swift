//
//  AnniPartnerNotificationListener.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

class AnniPartnerNotificationListener: NSObject {
    static let shared = AnniPartnerNotificationListener()
    private var firestoreListener: ListenerRegistration?
    private var currentUUID: String { CoupleStatusManager.getUserUniqueUUID() }
    
    private override init() { super.init() }
    
    // MARK: ✅ 对齐PartnerNotificationListener → 启动监听
    func startListening() {
        guard let coupleId = CoupleStatusManager.getPartnerId(), !currentUUID.isEmpty else {
            print("❌ 纪念日伴侣通知监听启动失败：缺少CoupleID/当前UUID")
            return
        }
        stopListening()
        
        // ✅ 监听路径完全对齐PartnerNotificationListener（仅后缀改为anni_tasks）
        let notifyRef = Firestore.firestore()
            .collection("couples")
            .document(coupleId)
            .collection("notification_tasks")
            .document(currentUUID)
            .collection("anni_tasks")
        
        // ✅ 监听逻辑完全复刻，单条指令独立处理
        firestoreListener = notifyRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ 纪念日通知指令监听异常：\(error.localizedDescription) → 3秒后自动重试")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.startListening() }
                return
            }
            guard let snapshot = snapshot, !snapshot.documents.isEmpty else { return }
            
            for doc in snapshot.documents {
                let data = doc.data()
                let taskId = data["taskId"] as? String ?? ""
                let isCreate = data["isCreate"] as? Bool ?? false
                guard !taskId.isEmpty else { continue }
                
                if isCreate {
                    // 创建纪念日通知
                    self.createAnniNotificationFromPartnerData(data: data)
                    print("✅ ✅ ✅ 伴侣端收到【纪念日创建通知】指令 → 任务[\(taskId)]")
                } else {
                    // 移除纪念日通知
                    AnniNotificationManager.shared.removeTaskNotification(taskId: taskId)
                    print("✅ ✅ ✅ 伴侣端收到【纪念日移除通知】指令 → 任务[\(taskId)]")
                }
                
                // ✅ 指令执行后删除，避免重复监听（对齐原逻辑）
                doc.reference.delete(completion: nil)
            }
        }
        print("✅ ✅ ✅ 纪念日伴侣通知指令监听已启动（本机UUID：\(currentUUID)）✅ ✅ ✅")
    }
    
    // MARK: ✅ 解析伴侣指令，创建本地纪念日通知
    private func createAnniNotificationFromPartnerData(data: [String: Any]) {
        let taskId = data["taskId"] as? String ?? ""
        let title = data["title"] as? String ?? "纪念日提醒"
        let body = data["body"] as? String ?? ""
        let isAllDay = data["isAllDay"] as? Bool ?? false
        let isReminderOn = data["isReminderOn"] as? Bool ?? true
        let repeatText = data["repeatText"] as? String ?? "Never"
        
        var triggerDate = Date()
        if let timestamp = data["triggerDate"] as? Timestamp {
            triggerDate = timestamp.dateValue()
        }
        
        AnniNotificationManager.shared.createSingleCycleTaskNotification(
            taskId: taskId, title: title, body: body,
            triggerDate: triggerDate, isAllDay: isAllDay,
            repeatText: repeatText, isReminderOn: isReminderOn
        )
    }
    
    // MARK: ✅ 对齐PartnerNotificationListener → 停止监听
    func stopListening() {
        firestoreListener?.remove()
        firestoreListener = nil
        print("✅ 纪念日伴侣通知指令监听已停止")
    }
}
