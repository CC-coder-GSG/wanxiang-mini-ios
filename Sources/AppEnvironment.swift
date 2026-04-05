import Foundation
import SwiftUI

@MainActor
@Observable
final class AppEnvironment {
    static let shared = AppEnvironment()

    var token: String? = nil
    var userId: String? = nil
    var isLoggedIn: Bool = false
    var errorMessage: String? = nil

    private init() {
        token = LocalStore.shared.currentToken()
        isLoggedIn = token != nil
    }

    func login(username: String, password: String) async {
        do {
            let data = try await APIClient.shared.login(username: username, password: password)
            token = data.access_token
            userId = data.user_id
            isLoggedIn = true
            LocalStore.shared.saveToken(data.access_token, username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        token = nil
        userId = nil
        isLoggedIn = false
        LocalStore.shared.clearToken()
    }

    func requireToken() throws -> String {
        guard let t = token, !t.isEmpty else { throw APIError.notLoggedIn }
        return t
    }

    /// 统一处理 API 错误：若是未登录则自动退出，其余返回错误描述
    @discardableResult
    func handle(_ error: Error) -> String? {
        if case APIError.notLoggedIn = error {
            logout()
            return nil
        }
        return error.localizedDescription
    }

    /// 仅用于 Xcode Preview，注入一个假 token
    static func preview(loggedIn: Bool = true) -> AppEnvironment {
        let env = AppEnvironment.shared
        env.token = loggedIn ? "preview_token" : nil
        env.isLoggedIn = loggedIn
        return env
    }
}
