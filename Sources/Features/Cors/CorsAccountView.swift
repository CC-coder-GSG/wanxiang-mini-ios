import SwiftUI

struct CorsAccountView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var accounts: [CorsAccount] = []
    @State private var keyword = ""
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var selectedAccount: CorsAccount? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("关键词", text: $keyword)
                        .submitLabel(.search)
                        .onSubmit { reload() }
                    if !keyword.isEmpty {
                        Button { keyword = ""; reload() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 10)

                if let err = errorMsg {
                    ErrorBanner(message: err) { errorMsg = nil }
                }

                List {
                    ForEach(accounts) { acc in
                        Button { selectedAccount = acc } label: {
                            CorsAccountRow(account: acc)
                        }
                        .listRowBackground(Color.appCard)
                    }

                    if totalPages > 1 {
                        HStack {
                            Button { loadPage(currentPage - 1) } label: {
                                Image(systemName: "chevron.left")
                            }.disabled(currentPage <= 1)
                            Spacer()
                            Text("\(currentPage) / \(totalPages)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Button { loadPage(currentPage + 1) } label: {
                                Image(systemName: "chevron.right")
                            }.disabled(currentPage >= totalPages)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { reload() }
            }
            .navigationTitle("差分账户管理")
            .navigationBarTitleDisplayMode(.inline)
            .task { reload() }
            .sheet(item: $selectedAccount) { acc in
                CorsAccountDetailSheet(account: acc)
            }

            if isLoading { LoadingOverlay(message: "加载中...") }
        }
    }

    private func reload() { loadPage(1) }

    private func loadPage(_ page: Int) {
        guard page >= 1 else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let token = try env.requireToken()
                let data = try await APIClient.shared.fetchCorsAccounts(keyword: keyword.isEmpty ? nil : keyword, page: page, size: 10, token: token)
                accounts = data.records
                totalPages = data.pages
                currentPage = page
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }
}

struct CorsAccountRow: View {
    let account: CorsAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(account.name)
                    .font(.subheadline.bold())
                Spacer()
                ActiveStatusBadge(status: account.activeStatus)
            }
            HStack(spacing: 16) {
                Label("类型 \(account.accountType)", systemImage: "tag")
                if let exp = account.expiredate {
                    Label(String.fromMillis(exp), systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// 激活状态：0=服务中 1=未激活 2=已到期
struct ActiveStatusBadge: View {
    let status: Int

    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case 0: return "服务中"
        case 1: return "未激活"
        case 2: return "已到期"
        default: return "未知"
        }
    }

    private var color: Color {
        switch status {
        case 0: return .green
        case 1: return .orange
        case 2: return .red
        default: return .secondary
        }
    }
}

/// 账号状态：0=正常 1=过期 2=禁用（保留供详情页使用）
struct StatusBadge: View {
    let status: Int

    var body: some View {
        Text(statusText)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var statusText: String {
        switch status {
        case 0: return "正常"
        case 1: return "过期"
        case 2: return "禁用"
        default: return "未知"
        }
    }

    private var statusColor: Color {
        switch status {
        case 0: return .green
        case 1: return .orange
        case 2: return .red
        default: return .secondary
        }
    }
}

struct CorsAccountDetailSheet: View {
    let account: CorsAccount
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var password: String? = nil
    @State private var showPassword = false
    @State private var customPassword = ""
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil
    @State private var showDiagnostic = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List {
                    Section {
                        Button {
                            showDiagnostic = true
                        } label: {
                            Label("诊断工具", systemImage: "stethoscope")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                    }
                    .listRowBackground(Color.appCard)

                    Section("账户信息") {
                        InfoRow(label: "账户名", value: account.name)
                        InfoRow(label: "ID", value: "\(account.id)")
                        HStack {
                            Text("激活状态").foregroundStyle(.secondary)
                            Spacer()
                            ActiveStatusBadge(status: account.activeStatus)
                        }
                        HStack {
                            Text("账号状态").foregroundStyle(.secondary)
                            Spacer()
                            StatusBadge(status: account.accountStatus)
                        }
                        InfoRow(label: "类型", value: "\(account.accountType)")
                        InfoRow(label: "激活时间", value: account.activeTime.map { String.fromMillis($0) } ?? "—")
                        InfoRow(label: "过期时间", value: account.expiredate.map { String.fromMillis($0) } ?? "—")
                        if let r = account.remark { InfoRow(label: "备注", value: r) }
                    }
                    .listRowBackground(Color.appCard)

                    Section("密码管理") {
                        if let p = password {
                            HStack {
                                Text(showPassword ? p : String(repeating: "●", count: p.count))
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    UIPasteboard.general.string = p
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        Button("查看当前密码") { checkPassword() }
                            .disabled(isLoading)
                        Button("重置密码") { resetPassword() }
                            .foregroundStyle(.orange)
                            .disabled(isLoading)
                    }
                    .listRowBackground(Color.appCard)

                    Section("自定义密码") {
                        TextField("输入新密码", text: $customPassword)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button("设置密码") { setCustomPassword() }
                            .disabled(isLoading || customPassword.isEmpty)
                    }
                    .listRowBackground(Color.appCard)

                    if let err = errorMsg {
                        Section {
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange).font(.subheadline)
                        }
                        .listRowBackground(Color.appCard)
                    }
                    if let msg = successMsg {
                        Section {
                            Label(msg, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.subheadline)
                        }
                        .listRowBackground(Color.appCard)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(account.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { dismiss() }
                    }
                }

                if isLoading { LoadingOverlay(message: "处理中...") }
            }
            .sheet(isPresented: $showDiagnostic) {
                DiagnosticView(account: account)
                    .environment(env)
            }
        }
    }

    private func checkPassword() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        Task {
            do {
                password = try await APIClient.shared.checkCorsPassword(id: account.id, token: token)
                showPassword = true
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func resetPassword() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        Task {
            do {
                let newPwd = try await APIClient.shared.resetCorsPassword(id: account.id, token: token)
                password = newPwd
                showPassword = true
                successMsg = "密码已重置"
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func setCustomPassword() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        Task {
            do {
                let resp = try await APIClient.shared.setCustomCorsPassword(id: account.id, password: customPassword, token: token)
                successMsg = resp.message.isEmpty ? "密码已更新" : resp.message
                customPassword = ""
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func statusLabel(_ s: Int) -> String {
        switch s { case 0: return "正常"; case 1: return "过期"; case 2: return "禁用"; default: return "未知" }
    }
}

#Preview("差分账户列表") {
    NavigationStack {
        CorsAccountView()
    }
    .environment(AppEnvironment.preview())
}

#Preview("账户行") {
    CorsAccountRow(account: CorsAccount(
        id: 1001,
        name: "cors_user_001",
        accountStatus: 0,
        accountType: 1,
        activeStatus: 1,
        activeTime: 1700000000000,
        expiredate: 1800000000000,
        registerdate: 1600000000000,
        remark: "测试账户"
    ))
    .padding()
}
