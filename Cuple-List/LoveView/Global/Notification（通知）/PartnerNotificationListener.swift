//
//  PartnerNotificationListener.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

class PartnerNotificationListener: NSObject {
    static let shared = PartnerNotificationListener()
    private var firestoreListener: ListenerRegistration?
    private var currentUUID: String { CoupleStatusManager.getUserUniqueUUID() } // ✅ 动态获取，避免初始化时未赋值
    
    private override init() { super.init() }
    
    func startListening() {
        guard let coupleId = CoupleStatusManager.getPartnerId(), !currentUUID.isEmpty else {
            print("❌ 通知监听启动失败：缺少CoupleID/当前UUID")
            return
        }
        stopListening()
        
        let notifyRef = Firestore.firestore()
            .collection("couples")
            .document(coupleId)
            .collection("notification_tasks")
            .document(currentUUID)
            .collection("tasks")
        
        // ✅ 强化监听：添加监听状态日志+异常兜底，确保回调必执行
        firestoreListener = notifyRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ 通知指令监听异常：\(error.localizedDescription) → 3秒后自动重试")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.startListening() }
                return
            }
            guard let snapshot = snapshot else { return }
            
            // ✅ 全量遍历+增量日志，确保无指令丢失
            for doc in snapshot.documents {
                let data = doc.data()
                let taskId = data["taskId"] as? String ?? ""
                let isCreate = data["isCreate"] as? Bool ?? false
                guard !taskId.isEmpty else { continue }
                
                if isCreate {
                    self.createNotificationFromPartnerData(data: data)
                    print("✅ ✅ ✅ 收到伴侣创建指令 → 自动创建任务[\(taskId)]通知")
                } else {
                    LocalNotificationManager.shared.removeTaskNotification(taskId: taskId)
                    print("✅ ✅ ✅ 收到伴侣移除指令 → 自动移除任务[\(taskId)]通知")
                }
            }
        }
        print("✅ ✅ ✅ 伴侣通知指令监听已启动（本机UUID：\(currentUUID)）✅ ✅ ✅")
    }
    
    private func createNotificationFromPartnerData(data: [String: Any]) {
        let taskId = data["taskId"] as? String ?? ""
        let title = data["title"] as? String ?? "待办任务"
        let body = data["body"] as? String ?? ""
        let isAllDay = data["isAllDay"] as? Bool ?? false
        let isReminderOn = data["isReminderOn"] as? Bool ?? false
        
        var triggerDate = Date()
        if let timestamp = data["triggerDate"] as? Timestamp {
            triggerDate = timestamp.dateValue()
        }
        
        // ✅ 强制创建通知，忽略临时权限问题
        LocalNotificationManager.shared.createTaskNotification(
            taskId: taskId, title: title, body: body,
            triggerDate: triggerDate, isAllDay: isAllDay, isReminderOn: isReminderOn
        )
    }
    
    func stopListening() {
        firestoreListener?.remove()
        firestoreListener = nil
        print("✅ 伴侣通知指令监听已停止")
    }
}
