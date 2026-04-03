//
//  CloudBaseConfig.swift
//  Cuple-List
//
//  腾讯云开发：环境 ID、网关、云函数名（数据库代理 coupleListDb）。
//

import Foundation

enum CloudBaseConfig {

    /// 在控制台复制环境 ID；也可在 Info.plist 增加 `CloudBaseEnvID`。
    private static let fallbackEnvironmentID = ""

    static var environmentID: String {
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "CloudBaseEnvID") as? String,
           !fromPlist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromPlist.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fallbackEnvironmentID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 访问 HTTP API 的 Bearer（Publishable Key / AccessToken / API Key），见控制台身份认证或密钥。
    /// 也可使用 Info.plist `CloudBaseAccessToken`。
    static var accessToken: String {
        if let t = Bundle.main.object(forInfoDictionaryKey: "CloudBaseAccessToken") as? String,
           !t.isEmpty { return t }
        if let t = UserDefaults.standard.string(forKey: "CloudBaseAccessToken"), !t.isEmpty { return t }
        return ""
    }

    /// 与 cloudfunctions/coupleListDb 部署名称一致。
    static let dbProxyFunctionName = "coupleListDb"

    enum RegionMode {
        case mainland
        case international
    }

    static var regionMode: RegionMode = .mainland

    static var gatewayHost: String? {
        let env = environmentID
        guard !env.isEmpty else { return nil }
        switch regionMode {
        case .mainland:
            return "https://\(env).api.tcloudbasegateway.com"
        case .international:
            return "https://\(env).api.intl.tcloudbasegateway.com"
        }
    }

    /// 集合监听器轮询间隔（云函数 HTTP 无法实现真正长连接时）。
    static var snapshotPollInterval: TimeInterval = 1.0

    static var isConfigured: Bool {
        gatewayHost != nil && !accessToken.isEmpty
    }
}
