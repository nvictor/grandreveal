//
//  RevealWebView.swift
//  GrandReveal
//
//  Created by Codex on 3/15/26.
//

import AppKit
import SwiftUI
import WebKit

struct RevealWebView: NSViewRepresentable {
    let source: DeckSource
    let reloadID: UUID
    let onLoadFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFailure: onLoadFailure)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: revealWindowInsetScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = false
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(source: source, reloadID: reloadID, in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?

        private let onLoadFailure: (String) -> Void
        private var lastLoadSignature: String?

        init(onLoadFailure: @escaping (String) -> Void) {
            self.onLoadFailure = onLoadFailure
        }

        func load(source: DeckSource, reloadID: UUID, in webView: WKWebView) {
            let signature = "\(source.title)::\(reloadID.uuidString)"
            guard signature != lastLoadSignature else {
                return
            }

            lastLoadSignature = signature

            do {
                let context = try source.makeLoadContext()
                webView.loadFileURL(context.entrypointURL, allowingReadAccessTo: context.readAccessURL)
            } catch {
                onLoadFailure(error.localizedDescription)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                webView.window?.makeFirstResponder(webView)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased(),
               ["http", "https"].contains(scheme) {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadFailure(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadFailure(error.localizedDescription)
        }
    }
}

private let revealWindowInsetScript = """
const style = document.createElement('style');
style.textContent = `
  .reveal .controls {
    right: max(28px, env(safe-area-inset-right));
    bottom: max(28px, env(safe-area-inset-bottom));
  }

  .reveal .progress {
    left: max(12px, env(safe-area-inset-left));
    right: max(12px, env(safe-area-inset-right));
    width: auto;
    bottom: max(8px, env(safe-area-inset-bottom));
  }
`;
document.head.appendChild(style);
"""
