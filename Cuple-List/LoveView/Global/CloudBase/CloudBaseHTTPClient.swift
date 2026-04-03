//
//  CloudBaseHTTPClient.swift
//  Cuple-List
//
//  通过云开发 HTTP 网关调用云函数（文档：/v1/functions/{name}）。
//  鉴权：在云开发平台开通身份认证后，使用 access_token、API Key 或 Publishable Key，置于 Authorization: Bearer …
//

import Foundation

enum CloudBaseHTTPError: Error, LocalizedError {
    case environmentNotConfigured
    case invalidURL
    case badStatus(code: Int, body: String?)
    case decodingFailed
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .environmentNotConfigured:
            return "未配置 CloudBase 环境 ID（CloudBaseConfig.environmentID / Info.plist CloudBaseEnvID）"
        case .invalidURL:
            return "无效的 CloudBase 请求 URL"
        case let .badStatus(code, body):
            return "CloudBase HTTP 错误 \(code): \(body ?? "")"
        case .decodingFailed:
            return "无法解析 CloudBase 响应"
        case .emptyResponse:
            return "CloudBase 响应为空"
        }
    }
}

/// 调用腾讯云开发 HTTP API（当前实现侧重「云函数」入口，便于用 Node `@cloudbase/node-sdk` 访问文档型数据库 / 存储）。
final class CloudBaseHTTPClient {

    static let shared = CloudBaseHTTPClient()

    /// 每次请求的 Bearer Token；登录接口见 `POST /auth/v1/signin`，或使用控制台发放的 API Key / Publishable Key。
    var authorizationBearerToken: String?

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - 云函数

    /// 调用云函数：`POST /v1/functions/{functionName}`
    func invokeFunction(
        name functionName: String,
        payload: [String: Any]? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard let host = CloudBaseConfig.gatewayHost else {
            completion(.failure(CloudBaseHTTPError.environmentNotConfigured))
            return
        }
        let path = "/v1/functions/\(functionName)"
        guard let url = URL(string: host + path) else {
            completion(.failure(CloudBaseHTTPError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authorizationBearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let bodyObj = payload ?? [String: Any]()
        guard JSONSerialization.isValidJSONObject(bodyObj) else {
            completion(.failure(CloudBaseHTTPError.decodingFailed))
            return
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyObj)
        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(CloudBaseHTTPError.badStatus(code: -1, body: nil)))
                return
            }
            let bodyText = data.flatMap { String(data: $0, encoding: .utf8) }
            guard (200 ... 299).contains(http.statusCode), let data else {
                completion(.failure(CloudBaseHTTPError.badStatus(code: http.statusCode, body: bodyText)))
                return
            }
            completion(.success(data))
        }
        task.resume()
    }

    /// 将云函数 JSON 响应中的顶层 `result` 解码为指定类型（若你的函数返回包装在 `result` 字段中）。
    func invokeFunctionDecodingResult<T: Decodable>(
        name functionName: String,
        payload: [String: Any]? = nil,
        as type: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        invokeFunction(name: functionName, payload: payload) { result in
            switch result {
            case let .failure(err):
                completion(.failure(err))
            case let .success(data):
                do {
                    let wrapper = try self.decoder.decode(CloudFunctionResultEnvelope<T>.self, from: data)
                    if let value = wrapper.result {
                        completion(.success(value))
                    } else {
                        completion(.failure(CloudBaseHTTPError.emptyResponse))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - 身份认证（用户名密码示例）

    struct SignInRequestBody: Encodable {
        let username: String
        let password: String
    }

    struct SignInResponseBody: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
    }

    /// `POST /auth/v1/signin`（需在云开发控制台开启对应登录方式并创建用户）
    func signInWithUsernamePassword(
        username: String,
        password: String,
        clientId: String? = nil,
        deviceId: String? = nil,
        completion: @escaping (Result<SignInResponseBody, Error>) -> Void
    ) {
        guard let host = CloudBaseConfig.gatewayHost else {
            completion(.failure(CloudBaseHTTPError.environmentNotConfigured))
            return
        }
        guard let url = URL(string: host + "/auth/v1/signin") else {
            completion(.failure(CloudBaseHTTPError.invalidURL))
            return
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var query: [URLQueryItem] = []
        if let clientId, !clientId.isEmpty {
            query.append(URLQueryItem(name: "client_id", value: clientId))
        }
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let finalURL = components?.url else {
            completion(.failure(CloudBaseHTTPError.invalidURL))
            return
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let deviceId, !deviceId.isEmpty {
            request.setValue(deviceId, forHTTPHeaderField: "x-device-id")
        }
        let body = SignInRequestBody(username: username, password: password)
        request.httpBody = try? JSONEncoder().encode(body)
        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse, let data else {
                completion(.failure(CloudBaseHTTPError.badStatus(code: -1, body: nil)))
                return
            }
            guard (200 ... 299).contains(http.statusCode) else {
                let bodyStr = String(data: data, encoding: .utf8)
                completion(.failure(CloudBaseHTTPError.badStatus(code: http.statusCode, body: bodyStr)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(SignInResponseBody.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

private struct CloudFunctionResultEnvelope<T: Decodable>: Decodable {
    let result: T?
}
