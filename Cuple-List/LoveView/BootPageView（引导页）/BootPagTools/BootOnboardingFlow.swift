//
//  BootOnboardingFlow.swift
//  Cuple-List
//
//  Created by wanghaojun.
//
import UIKit

/// 引导流程顺序（与导航 push 链一致），用于未完成的用户回到首页 Tab 时恢复到对应页。
enum BootOnboardingStep: Int, CaseIterable {
    case welcome = 0
    case nameInput = 1
    case what = 2
    case avatar = 3
    case togetherDate = 4
    case things = 5
    case story = 6
    case set = 7
    case allow = 8
    case bootPage = 9
}

enum BootOnboardingFlow {
    static let stepUserDefaultsKey = "bootOnboardingStepRaw"
    
    /// 当前引导进度（未完成引导时由 `recordStep` 与各页 `viewDidAppear` 维护）
    static var persistedStep: BootOnboardingStep {
        let raw = UserDefaults.standard.integer(forKey: stepUserDefaultsKey)
        return BootOnboardingStep(rawValue: raw) ?? .welcome
    }
    
    static func recordStep(_ step: BootOnboardingStep) {
        guard !UserDefaults.standard.bool(forKey: "hasLaunchedOnce") else { return }
        UserDefaults.standard.set(step.rawValue, forKey: stepUserDefaultsKey)
    }
    
    static func clearOnboardingProgress() {
        UserDefaults.standard.removeObject(forKey: stepUserDefaultsKey)
    }
    
    /// 除 `welcome` 外返回用于恢复的页面实例（栈为 `[WelcomeView, 该页]`）
    static func viewController(for step: BootOnboardingStep) -> UIViewController? {
        switch step {
        case .welcome: return nil
        case .nameInput: return BootNameInputViewController()
        case .what: return WhatView()
        case .avatar: return BootAvatarSetupViewController()
        case .togetherDate: return BootTogetherDateViewController()
        case .things: return BootThingsViewController()
        case .story: return StoryController()
        case .set: return SetView()
        case .allow: return AllowView()
        case .bootPage: return BootPageView()
        }
    }
    
    /// 与正常 push 顺序一致，用于恢复未完成引导时的完整导航栈；根 `WelcomeView` 使用 `bootResumeStep: .welcome`，避免再次 `resume`。
    private static let onboardingPushOrder: [BootOnboardingStep] = [
        .nameInput, .what, .avatar, .togetherDate, .things, .story, .set, .allow, .bootPage
    ]
    
    /// 从 Welcome 起叠到 `through` 为止的整链，返回后点返回会逐级回到上一页，而不是直接回到 Welcome。
    static func navigationStackThrough(through step: BootOnboardingStep) -> [UIViewController] {
        guard step != .welcome else {
            return [WelcomeView(bootResumeStep: .welcome)]
        }
        var stack: [UIViewController] = [WelcomeView(bootResumeStep: .welcome)]
        for s in onboardingPushOrder {
            guard let vc = viewController(for: s) else { continue }
            stack.append(vc)
            if s == step { break }
        }
        return stack
    }
    
    static func finishAndShowHome(from vc: UIViewController) {
        UserDefaults.standard.set(true, forKey: "hasLaunchedOnce")
        UserDefaults.standard.synchronize()
        clearOnboardingProgress()
        guard let tab = vc.tabBarController as? MomoTabBarController,
              let nav = vc.navigationController else { return }
        tab.setTabBarHidden(false)
        tab.tabBar.isUserInteractionEnabled = true
        nav.setViewControllers([HomeViewController()], animated: true)
    }
}

enum BootOnboardingFeedback {
    private static let continueImpact = UIImpactFeedbackGenerator(style: .light)
    private static let selectionFeedback = UISelectionFeedbackGenerator()

    static func playContinueButton() {
        continueImpact.prepare()
        continueImpact.impactOccurred()
    }

    /// 引导页切换选项（如性别）
    static func playSelectionChanged() {
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }
}
