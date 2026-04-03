//
//  Keys.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import Foundation//导入 Foundation 框架，该框架包含了 UserDefaults 类。

struct NotificationName {
    static let DatabaseItemDidChanged = NSNotification.Name("notification_DatabaseItemDidChanged")
}

struct UserDefaultsKey {//定义了一个名为 UserDefaultsKey 的结构体，该结构体用于存放 UserDefaults 键值对的键名。
	static let HaveShownBaseVC = "HaveShownBaseVCUserDefaultsKey"//定义了一个名为 HaveShownBaseVC 的静态常量，其值为 "HaveShownBaseVCUserDefaultsKey"。该常量用于存储一个布尔值，表示用户是否已经看过基础视图控制器。
	static let ShouldCheckSubscriptionNextStart = "ShouldCheckSubscriptionNextStartUserDefaultsKey"//定义了一个名为 ShouldCheckSubscriptionNextStart 的静态常量，其值为//"ShouldCheckSubscriptionNextStartUserDefaultsKey"。该常量用于存储一个布尔值，表示是否应该在下一次启动应用时检查订阅状态。
    static let hasLaunchedBefore = "hasLaunchedOnceUserDefaultsKey"//检查用户是否初次进入
}
