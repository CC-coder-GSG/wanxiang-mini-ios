import SwiftUI
import WebKit

struct InWebView: View {
    let url: URL
    @State private var isLoading = true
    @State private var title = ""

    var body: some View {
        WebViewRepresentable(url: url, isLoading: $isLoading, pageTitle: $title)
            .navigationTitle(title.isEmpty ? "网页" : title)
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let wk = WKWebView()
        wk.navigationDelegate = context.coordinator
        wk.load(URLRequest(url: url))
        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        init(_ parent: WebViewRepresentable) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title ?? ""
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

#Preview("Web视图") {
    NavigationStack {
        InWebView(url: URL(string: "https://www.apple.com")!)
    }
}
