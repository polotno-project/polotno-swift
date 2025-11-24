import SwiftUI
import UIKit
import WebKit

struct EditorSavePayload: Codable {
    let docJson: String
    let previewBase64: String

    func previewImage() -> UIImage? {
        guard let data = Data(base64Encoded: previewBase64) else { return nil }
        return UIImage(data: data)
    }
}

struct EditorWebView: UIViewRepresentable {
    let initialDocumentJSON: String
    let onSave: (EditorSavePayload) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.javaScriptEnabled = true
        enableLocalFileAccess(on: configuration)
        configuration.userContentController = WKUserContentController()
        context.coordinator.attach(to: configuration.userContentController)
        context.coordinator.injectConsoleBridge(into: configuration.userContentController)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        loadEditorBundle(into: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nothing to update; the entire editor lifecycle happens in JS.
    }

    private func loadEditorBundle(into webView: WKWebView) {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Editor") else {
            assertionFailure("Editor bundle is missing. Run npm run build:ios before launching.")
            return
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
    }
}

private func enableLocalFileAccess(on configuration: WKWebViewConfiguration) {
    let allowFileAccessSelector = NSSelectorFromString("setAllowFileAccessFromFileURLs:")
    if configuration.preferences.responds(to: allowFileAccessSelector) {
        _ = configuration.preferences.perform(allowFileAccessSelector, with: NSNumber(value: true))
    }

    let allowUniversalAccessSelector = NSSelectorFromString("setAllowUniversalAccessFromFileURLs:")
    if configuration.responds(to: allowUniversalAccessSelector) {
        _ = configuration.perform(allowUniversalAccessSelector, with: NSNumber(value: true))
    }
}

extension EditorWebView {
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let parent: EditorWebView
        private weak var userContentController: WKUserContentController?
        private var injectedInitialDoc = false

        init(parent: EditorWebView) {
            self.parent = parent
        }

        func attach(to controller: WKUserContentController) {
            userContentController = controller
            controller.add(self, name: "editor")
        }

        func injectConsoleBridge(into controller: WKUserContentController) {
            let source = """
            (function() {
              const send = (level, message) => {
                const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.console;
                if (handler && handler.postMessage) {
                  handler.postMessage({ level, message });
                }
              };
              ['log', 'warn', 'error'].forEach(level => {
                const original = console[level];
                console[level] = function(...args) {
                  try {
                    const formatted = args.map(arg => {
                      if (typeof arg === 'string') { return arg; }
                      try {
                        return JSON.stringify(arg);
                      } catch (_) {
                        return String(arg);
                      }
                    }).join(' ');
                    send(level, formatted);
                  } catch (_) {}
                  if (original) {
                    original.apply(console, args);
                  }
                };
              });
              window.addEventListener('error', event => {
                if (!event) { return; }
                const location = event.filename ? `${event.filename}:${event.lineno}` : '';
                send('error', `JS Error: ${event.message} ${location}`);
              });
              window.addEventListener('unhandledrejection', event => {
                if (!event) { return; }
                const reason = event.reason && event.reason.stack ? event.reason.stack : event.reason;
                send('error', `Unhandled promise rejection: ${reason}`);
              });
            })();
            """
            let userScript = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            controller.addUserScript(userScript)
            controller.add(self, name: "console")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "editor":
                guard let payload = parseSavePayload(from: message.body) else {
                    return
                }
                parent.onSave(payload)
            case "console":
                if let dict = message.body as? [String: Any],
                   let level = dict["level"] as? String,
                   let text = dict["message"] as? String {
                    print("[Editor console][\(level)] \(text)")
                }
            default:
                break
            }
        }

        private func parseSavePayload(from body: Any) -> EditorSavePayload? {
            guard
                let dictionary = body as? [String: Any],
                dictionary["type"] as? String == "save",
                let docJson = dictionary["docJson"] as? String,
                let preview = dictionary["previewBase64"] as? String
            else {
                return nil
            }

            return EditorSavePayload(docJson: docJson, previewBase64: preview)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectInitialDocument(into: webView)
            debugDocumentState(in: webView, context: "didFinish")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Editor webView navigation failed with error: \(error.localizedDescription)")
            debugDocumentState(in: webView, context: "didFail navigation")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Editor webView provisional navigation failed: \(error.localizedDescription)")
            debugDocumentState(in: webView, context: "didFail provisional")
        }

        private func injectInitialDocument(into webView: WKWebView) {
            guard !injectedInitialDoc,
                  let data = parent.initialDocumentJSON.data(using: .utf8) else {
                return
            }

            injectedInitialDoc = true
            let base64 = data.base64EncodedString()
            let script = """
            window.__polotnoReceiveInitialDoc && window.__polotnoReceiveInitialDoc(atob('\(base64)'));
            """

            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        deinit {
            userContentController?.removeScriptMessageHandler(forName: "editor")
            userContentController?.removeScriptMessageHandler(forName: "console")
        }

        private func debugDocumentState(in webView: WKWebView, context: String) {
            let script = """
            (function() {
              const scripts = Array.from(document.scripts).map(s => s.src || '[inline]');
              const links = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).map(l => l.href || '[inline]');
              return { readyState: document.readyState, scripts, links };
            })();
            """

            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("Editor debug (\(context)) JS evaluation failed: \(error.localizedDescription)")
                    return
                }

                guard let payload = result as? [String: Any] else {
                    print("Editor debug (\(context)): unexpected JS payload \(String(describing: result))")
                    return
                }

                let readyState = payload["readyState"] ?? "unknown"
                print("Editor document readyState (\(context)): \(readyState)")

                if let scripts = payload["scripts"] as? [String] {
                    print("Editor scripts (\(context)): \(scripts)")
                }

                if let links = payload["links"] as? [String] {
                    print("Editor styles (\(context)): \(links)")
                }
            }
        }
    }
}

