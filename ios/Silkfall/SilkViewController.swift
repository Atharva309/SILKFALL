import UIKit
import WebKit

/// Shows Silkfall full-screen and bridges the few things a web page can't do on its own:
/// keeping the screen awake, remembering settings reliably, and allowing tilt without a prompt.
final class SilkViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {

    private var webView: WKWebView!
    private let defaults = UserDefaults.standard
    private let savedKeys = ["silkfall.v1", "silkfall.hinted"]
    private var keepAwake = true

    override func loadView() {
        let contentController = WKUserContentController()
        contentController.add(WeakMessageHandler(self), name: "silk")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.uiDelegate = self
        web.navigationDelegate = self
        webView = web
        view = web
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadPage()
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    /// Loads the bundled page, with the latest saved settings injected first.
    private func loadPage() {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: startupScript(),
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
        if let page = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("""
            <body style="background:#000;color:#ece2ce;font:18px -apple-system;display:grid;place-items:center;height:100vh;margin:0">
            Silkfall couldn't find its page inside the app. Rebuild it from GitHub and reinstall.
            </body>
            """, baseURL: nil)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyKeepAwake()
    }

    @objc private func becameActive() {
        applyKeepAwake()
    }

    private func applyKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled = keepAwake
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    // Runs before the page's own script: marks the app, restores saved settings,
    // and mirrors every settings save into UserDefaults so nothing is lost.
    private func startupScript() -> String {
        var js = "window.SILKFALL_NATIVE = true;\n"
        for key in savedKeys {
            if let value = defaults.string(forKey: key) {
                js += "try { localStorage.setItem(\(jsLiteral(key)), \(jsLiteral(value))); } catch (e) {}\n"
            }
        }
        js += """
        (function () {
          var original = Storage.prototype.setItem;
          Storage.prototype.setItem = function (k, v) {
            original.call(this, k, v);
            try { window.webkit.messageHandlers.silk.postMessage({ type: "store", key: String(k), value: String(v) }); } catch (e) {}
          };
        })();
        """
        return js
    }

    private func jsLiteral(_ text: String) -> String {
        // Encode as a one-element JSON array, then strip the brackets to get a safe JS string literal.
        guard let data = try? JSONSerialization.data(withJSONObject: [text], options: []),
              let json = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(json.dropFirst().dropLast())
    }

    // MARK: - Messages from the page

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "store":
            if let key = body["key"] as? String, savedKeys.contains(key), let value = body["value"] as? String {
                defaults.set(value, forKey: key)
            }
        case "awake":
            if let on = body["on"] as? Bool {
                keepAwake = on
                applyKeepAwake()
            }
        default:
            break
        }
    }

    // MARK: - Tilt parallax: allow motion access without asking

    func webView(_ webView: WKWebView,
                 requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    // If iPadOS ever stops the web content (for example under memory pressure), load it again.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadPage()
    }
}

/// Avoids a retain cycle between the web view's content controller and the view controller.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
