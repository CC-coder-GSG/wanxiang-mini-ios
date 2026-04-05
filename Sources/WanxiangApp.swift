import SwiftUI
import SwiftData

@main
struct WanxiangApp: App {
    @State private var env = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ContentRouter()
                .environment(env)
        }
        .modelContainer(LocalStore.shared.container)
    }
}

struct ContentRouter: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.isLoggedIn {
                HomeView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: env.isLoggedIn)
    }
}
