import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showLogoutConfirm = false

    private let items: [(String, String, AnyView)] = [
        ("设备注册", "checkmark.seal.fill", AnyView(RegisterView())),
        ("软件注册码", "key.fill", AnyView(SoftwareListView())),
        ("差分账户管理", "person.2.fill", AnyView(CorsAccountView())),
        ("万象地信", "map.fill", AnyView(CrossRegionView())),
        ("注册日志", "clock.arrow.circlepath", AnyView(RegisterLogView())),
        ("万向官网", "globe", AnyView(InWebView(url: URL(string: "https://www.sinognss.com")!))),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(items, id: \.0) { item in
                        NavigationLink {
                            item.2
                        } label: {
                            HomeCell(title: item.0, icon: item.1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle("迷你万象")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLogoutConfirm = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .confirmationDialog("确定退出登录？", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("退出登录", role: .destructive) { env.logout() }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

struct HomeCell: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview("主菜单") {
    HomeView()
        .environment(AppEnvironment.preview())
}
