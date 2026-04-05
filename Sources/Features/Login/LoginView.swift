import SwiftUI

struct LoginView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @FocusState private var focused: Field?

    enum Field { case username, password }

    init() {
        _username = State(initialValue: LocalStore.shared.savedUsername())
        _password = State(initialValue: LocalStore.shared.savedPassword())
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 60)

                    // Logo area
                    VStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(.primary)
                        Text("迷你万象")
                            .font(.title2.bold())
                        Text("设备管理平台")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Form
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("账号", text: $username)
                                .keyboardType(.asciiCapable)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($focused, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focused = .password }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            SecureField("密码", text: $password)
                                .focused($focused, equals: .password)
                                .submitLabel(.done)
                                .onSubmit { login() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Error
                    if let err = env.errorMessage {
                        ErrorBanner(message: err) {
                            env.errorMessage = nil
                        }
                    }

                    // Login button
                    Button(action: login) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("登 录")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .disabled(isLoading)
                }
                .padding(.bottom, 40)
            }

            if isLoading {
                LoadingOverlay(message: "登录中...")
            }
        }
    }

    private func login() {
        guard !username.isEmpty, !password.isEmpty else {
            env.errorMessage = "请输入账号和密码"
            return
        }
        focused = nil
        isLoading = true
        env.errorMessage = nil
        Task {
            await env.login(username: username, password: password)
            isLoading = false
        }
    }
}

#Preview("登录页") {
    LoginView()
        .environment(AppEnvironment.preview(loggedIn: false))
}
