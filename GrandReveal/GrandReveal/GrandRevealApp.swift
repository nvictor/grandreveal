//
//  GrandRevealApp.swift
//  GrandReveal
//
//  Created by Victor Noagbodji on 3/15/26.
//

import SwiftUI

@main
struct GrandRevealApp: App {
    @NSApplicationDelegateAdaptor(GrandRevealAppDelegate.self) private var appDelegate
    @FocusedValue(\.grandRevealFocusedModel) private var focusedModel
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        WindowGroup {
            GrandRevealWindowRootView()
        }
        .defaultSize(width: 1280, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Deck") {
                    focusedModel?.openDeckPicker()
                }
                .keyboardShortcut("o")
                .disabled(focusedModel == nil)

                Button("Return to Launcher") {
                    focusedModel?.reopenLauncher()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(focusedModel?.activeDeck == nil)
            }

            CommandGroup(after: .pasteboard) {
                Button("Reload Deck") {
                    focusedModel?.reload()
                }
                .keyboardShortcut("r")
                .disabled(focusedModel?.activeDeck == nil)
            }

        }
        .commands {
            CheckForUpdatesCommands(updater: updater)
        }
    }
}

@MainActor
final class RecentDeckCoordinator {
    static let shared = RecentDeckCoordinator()

    private weak var model: GrandRevealModel?
    private var pendingURLs: [URL] = []

    private init() {}

    func register(_ model: GrandRevealModel) {
        self.model = model
        openPendingURLs()
    }

    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let model else {
            pendingURLs.append(url)
            return true
        }

        return model.loadDeck(at: url)
    }

    private func openPendingURLs() {
        guard let model, pendingURLs.isEmpty == false else {
            return
        }

        let urls = pendingURLs
        pendingURLs.removeAll()

        for url in urls {
            model.loadDeck(at: url)
        }
    }
}

@MainActor
final class GrandRevealAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        RecentDeckCoordinator.shared.open(URL(fileURLWithPath: filename))
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        var didOpenAllFiles = true

        for filename in filenames {
            if RecentDeckCoordinator.shared.open(URL(fileURLWithPath: filename)) == false {
                didOpenAllFiles = false
            }
        }

        sender.reply(toOpenOrPrint: didOpenAllFiles ? .success : .failure)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            RecentDeckCoordinator.shared.open(url)
        }
    }
}
