import SwiftUI
import WebKit

struct DeezerWebView: UIViewRepresentable {
    let url: URL
    let onARL: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onARL: onARL) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = context.coordinator
        web.configuration.websiteDataStore.httpCookieStore.add(context.coordinator)
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        let onARL: (String) -> Void
        private var captured = false

        init(onARL: @escaping (String) -> Void) { self.onARL = onARL }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) { scan(cookieStore) }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scan(webView.configuration.websiteDataStore.httpCookieStore)
        }

        private func scan(_ store: WKHTTPCookieStore) {
            guard !captured else { return }
            store.getAllCookies { [weak self] cookies in
                guard let self, !self.captured else { return }
                guard let arl = cookies.first(where: {
                    $0.name == "arl" && $0.domain.contains("deezer.com")
                }), !arl.value.isEmpty else { return }
                self.captured = true
                self.onARL(arl.value)
            }
        }
    }
}

struct DeezerLoginSheet: View {
    @EnvironmentObject var app: AppState
    private let loginURL = URL(string: "https://www.deezer.com/login")!

    var body: some View {
        NavigationStack {
            ZStack {
                DeezerWebView(url: loginURL) { arl in
                    Task { @MainActor in app.webLoginCaptured(arl: arl) }
                }
                if app.busy {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    ProgressView("Signing in…").tint(DZ.accent)
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Log in with Deezer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { app.showLoginWeb = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let e = app.loginError, !app.busy {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text(e).foregroundStyle(DZ.textPri).font(.callout)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(DZ.panelBG)
                }
            }
        }
    }
}
