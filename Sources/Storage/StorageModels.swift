import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class UserAccount {
    var username: String
    var password: String
    var accessToken: String
    var updatedAt: Date

    init(username: String = "", password: String = "", accessToken: String = "", updatedAt: Date = .now) {
        self.username = username
        self.password = password
        self.accessToken = accessToken
        self.updatedAt = updatedAt
    }
}

@Model
final class RegisterHistory {
    var sn: String
    var operateTime: Date
    var registerTime: Date?
    var extendTime: Date?

    init(sn: String, operateTime: Date = .now) {
        self.sn = sn
        self.operateTime = operateTime
    }
}

// MARK: - LocalStore

@MainActor
final class LocalStore: ObservableObject {
    static let shared = LocalStore()

    let container: ModelContainer

    private init() {
        let schema = Schema([UserAccount.self, RegisterHistory.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        container = try! ModelContainer(for: schema, configurations: config)
    }

    // MARK: Token

    func saveToken(_ token: String, username: String, password: String) {
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<UserAccount>()
        let existing = (try? ctx.fetch(descriptor)) ?? []
        if let account = existing.first {
            account.accessToken = token
            account.username = username
            account.password = password
            account.updatedAt = .now
        } else {
            ctx.insert(UserAccount(username: username, password: password, accessToken: token))
        }
        try? ctx.save()
    }

    func loadAccount() -> UserAccount? {
        let ctx = container.mainContext
        return (try? ctx.fetch(FetchDescriptor<UserAccount>()))?.first
    }

    func currentToken() -> String? {
        let t = loadAccount()?.accessToken
        return (t?.isEmpty == false) ? t : nil
    }

    func savedUsername() -> String { loadAccount()?.username ?? "" }
    func savedPassword() -> String { loadAccount()?.password ?? "" }

    func clearToken() {
        let ctx = container.mainContext
        if let account = loadAccount() {
            account.accessToken = ""
            try? ctx.save()
        }
    }

    // MARK: Register History

    func addHistory(sn: String) -> RegisterHistory {
        let ctx = container.mainContext
        let record = RegisterHistory(sn: sn)
        ctx.insert(record)
        try? ctx.save()
        return record
    }

    func updateHistory(record: RegisterHistory, registerTime: Date? = nil, extendTime: Date? = nil) {
        if let t = registerTime { record.registerTime = t }
        if let t = extendTime { record.extendTime = t }
        try? container.mainContext.save()
    }

    func allHistory() -> [RegisterHistory] {
        let desc = FetchDescriptor<RegisterHistory>(sortBy: [SortDescriptor(\.operateTime, order: .reverse)])
        return (try? container.mainContext.fetch(desc)) ?? []
    }
}
