//
//  GrandRevealApp.swift
//  GrandReveal
//
//  Created by Victor Noagbodji on 3/15/26.
//

import SwiftUI

@main
struct GrandRevealApp: App {
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
