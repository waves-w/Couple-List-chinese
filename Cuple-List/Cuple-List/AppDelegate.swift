//
//  AppDelegate.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit
import Sentry
import RevenueCat
import CoreData
import MagicalRecord
import KeychainSwift
import CocoaLumberjack



@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // ✅ 修复：保存 Timer 引用，避免内存泄漏
    private var overdueCheckTimer: Timer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // ✅ 先初始化日志系统（不涉及异常处理）【we
        setupLogger()
        
        // 1. 腾讯云开发：数据库经云函数 coupleListDb；请在 Info.plist 配置 CloudBaseEnvID、CloudBaseAccessToken
        CloudBaseHTTPClient.shared.authorizationBearerToken = CloudBaseConfig.accessToken
        if !CloudBaseConfig.isConfigured {
            print("⚠️ CloudBase 未配置：请设置 CloudBaseEnvID 与 CloudBaseAccessToken，并部署 cloudfunctions/coupleListDb")
        }
        MagicalRecord.setupAutoMigratingCoreDataStack()
        // ✅ 尽早初始化键盘可见性标志，供列表 cell 等在键盘弹起时跳过 AI 抠图，减轻发热
        KeyboardVisibleFlag.start()
        MagicalRecord.setLoggingLevel(.off) // 关闭 MagicalRecord 的 "Created new private queue context" / "→ Saving ..." 等循环日志
        configurePurchases()
        
        // MARK: ✅ 崩溃捕获系统初始化
        CrashLogger.shared.setup()
        
        // 2. 用户UUID打印（原有逻辑保留）
        let userUUID = UserDefaults.getUserUniqueUUID()
        print("✅ App全局启动，用户唯一UUID：\(userUUID)")
        
        // 3. 纪念日相关初始化（原有逻辑保留）
        _ = AnniManger.manager
        _ = AnniNotificationManager.shared
   
        PartnerNotificationListener.shared.startListening()
        AnniPartnerNotificationListener.shared.startListening()
        
        // MARK: ✅ 【核心新增2】通知权限请求已移至引导页 AllowView，不在 AppDelegate 中请求
        // ✅ 通知权限请求将在用户进入 AllowView 页面时自动弹出
        
        // 4. 纪念日通知补建逻辑（原有逻辑保留）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let allModels = AnniManger.manager.fetchAnniModels()
            allModels.forEach { model in
                if model.isReminder, let taskId = model.id {
                    AnniNotificationManager.shared.checkAndCreateNextNotification(for: taskId)
                }
            }
            print("✅ APP启动检测完成：已校验所有任务的通知状态，缺失则自动补建")
        }
        
        // MARK: ✅ 【核心新增3】启动时检查逾期任务并自动扣分
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.checkAndDeductOverdueTasks()
        }
        
        // MARK: ✅ 【核心新增4】定期检查逾期任务（每5分钟检查一次）
        // ✅ 修复：保存 Timer 引用，避免内存泄漏
        overdueCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkAndDeductOverdueTasks()
        }
        
        // MARK: ✅ 【核心新增5】确保 ScoreManager 监听器在链接后启动（延迟启动，等待链接状态确定）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if CoupleStatusManager.getPartnerId() != nil {
                ScoreManager.shared.refreshScoreListener()
                print("✅ App启动后，已确保 ScoreManager 监听器启动")
            }
        }
        
        // MARK: ✅ 【核心新增6】应用启动时更新角标数量
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            BadgeManager.shared.updateBadgeCount()
        }
        
        // MARK: ✅ 【核心新增7】应用启动时启动全局链接监听器（如果未链接，检测重新链接）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if !CoupleStatusManager.shared.isUserLinked {
                CoupleStatusManager.shared.startGlobalLinkListener()
                print("✅ App启动后，已启动全局链接监听器（检测重新链接）")
            }
        }
        
        // 5. Sentry埋点（原有逻辑保留）
#if DEBUG
#else
        SentrySDK.start { options in
            options.dsn = "https://1bf69558d55e7bf39920d62429f72817@o4509135364554752.ingest.us.sentry.io/4510383740616704"
            options.debug = true
            options.tracesSampleRate = 1.0
            options.experimental.enableLogs = true
        }
#endif
        return true
    }
    
    // MARK: - UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // 场景会话丢弃处理
    }
    
//    @objc func printAvailableFonts() {
//        print("======== 项目中可用的所有字体名称 ========")
//        let familyNames = UIFont.familyNames.sorted()
//        
//        for familyName in familyNames {
//            print("字体家族: \(familyName)")
//            
//            let fontNames = UIFont.fontNames(forFamilyName: familyName).sorted()
//            
//            for fontName in fontNames {
//                print("    - 字体名称: \(fontName)")
//            }
//        }
//        print("========================================")
//    }
}

extension AppDelegate: PurchasesDelegate {
    func configurePurchases() {
        Purchases.logLevel = .debug
        let keychain = KeychainSwift()
        keychain.synchronizable = true
        Purchases.proxyURL = URL(string: "https://api.rc-backup.com")
        Purchases.configure(
            with: Configuration.Builder(withAPIKey: "appl_cNRSoyBfjDSEYSqhxwEnbghogIn")
//                .with(appUserID: keychain.get("RevenueCat App User ID"))
                .with(entitlementVerificationMode: .informational)
        )
        keychain.set(Purchases.shared.appUserID, forKey: "RevenueCat App User ID")
        Purchases.shared.delegate = self
        print(Purchases.shared.appUserID)
    }
    
    func purchases(_ purchases: Purchases, receivedUpdated purchaserInfo: CustomerInfo) {
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.HaveRestoredOnceWhenStart) {
            UserDefaults.standard.set(true, forKey: UserDefaultsKey.HaveRestoredOnceWhenStart)
        }
    }
}

extension UserDefaultsKey {
    static let HaveRestoredOnceWhenStart = "DidRestoreOnceOnLaunch"
}

// MARK: ✅ CocoaLumberjack 配置
extension AppDelegate {
    private func setupLogger() {
        // 配置日志级别
        #if DEBUG
        DDLog.add(DDOSLogger.sharedInstance, with: .debug) // Debug 模式：显示所有日志
        #else
        DDLog.add(DDOSLogger.sharedInstance, with: .info) // Release 模式：只显示 Info 及以上级别
        #endif
        
        // 配置文件日志（保存到文件）
        let fileLogger: DDFileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24小时滚动一次
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7 // 保留7天的日志
        fileLogger.maximumFileSize = 1024 * 1024 * 2 // 单个文件最大2MB
        DDLog.add(fileLogger, with: .debug)
        
        // 写一条初始日志，确保日志文件被创建
        fileLogger.flush() // 立即刷新，确保日志写入文件
    }
}

// MARK: ✅ 逾期任务检查：逾期未完成 → 扣分（有记录）；逾期后完成 → 加0分（有记录）；头像下分数按记录汇总
extension AppDelegate {
    private func checkAndDeductOverdueTasks() {
        let allTasks = DbManager.manager.fetchListModels()
        print("🔍 开始检查逾期任务，共\(allTasks.count)个任务")
        
        ScoreManager.shared.getAllScoreRecords { allRecords in
            for task in allTasks {
                guard let taskId = task.id, task.points > 0 else { continue }
                
                if task.isOverdue && !task.isCompleted {
                    let hasExpiredRecord = allRecords.contains { record in
                        record.taskId == taskId && record.score < 0 && !record.isOnTime
                    }
                    if !hasExpiredRecord {
                        print("⚠️ 发现逾期未完成任务[\(taskId)]，执行扣分（保留记录）")
                        ScoreManager.shared.minusScoreForExpiredTask(task)
                    }
                }
            }
        }
    }
}
