//
//  GrandRevealApp.swift
//  GrandReveal
//
//  Created by Victor Noagbodji on 3/15/26.
//

import SwiftUI

@main
struct GrandRevealApp: App {
    @StateObject private var model = GrandRevealModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1440, height: 810)
        .commands {
            CommandMenu("GrandReveal") {
                Button("Open Deck") {
                    model.openDeckPicker()
                }
                .keyboardShortcut("o")

                Button("Load Demo") {
                    model.loadDemo()
                }
                .keyboardShortcut("d")

                Divider()

                Button("Reload Deck") {
                    model.reload()
                }
                .keyboardShortcut("r")
                .disabled(model.activeDeck == nil)

                Button("Return to Launcher") {
                    model.reopenLauncher()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(model.activeDeck == nil)
            }
        }
    }
}
