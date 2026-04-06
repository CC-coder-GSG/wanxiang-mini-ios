import SwiftUI
import WebKit

struct InWebView: View {
    let url: URL
    @State private var isLoading = true
    @State private var title = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            WebViewRepresentable(url: url, isLoading: $isLoading, pageTitle: $title, errorMessage: $errorMessage)
                .navigationTitle(title.isEmpty ? "司南官网" : title)
                .navigationBarTitleDisplayMode(.inline)

            if isLoading {
                ProgressView("页面加载中...")
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            if let errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let wk = WKWebView(frame: .zero, configuration: config)
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
            parent.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title ?? ""
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title ?? ""
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.errorMessage = "页面加载失败：\(error.localizedDescription)"
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.errorMessage = "页面加载失败：\(error.localizedDescription)"
        }
    }
}

#Preview("Web视图") {
    NavigationStack {
        InWebView(url: URL(string: "https://www.apple.com")!)
    }
}
