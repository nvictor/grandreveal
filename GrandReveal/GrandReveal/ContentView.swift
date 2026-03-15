//
//  ContentView.swift
//  GrandReveal
//
//  Created by Victor Noagbodji on 3/15/26.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class GrandRevealModel: ObservableObject {
    @Published var activeDeck: DeckSource?
    @Published var errorMessage: String?
    @Published var reloadID = UUID()

    private var activeSecurityScopedURLs: [URL] = []

    deinit {
        for url in activeSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func loadDemo() {
        clearSecurityScopedAccess()
        errorMessage = nil
        activeDeck = .bundledDemo
        reloadID = UUID()
    }

    func reopenLauncher() {
        clearSecurityScopedAccess()
        activeDeck = nil
    }

    func reload() {
        reloadID = UUID()
    }

    func openDeckPicker() {
        let panel = NSOpenPanel()
        panel.prompt = "Open Deck"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.html]

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            Task { @MainActor in
                self?.loadDeck(at: url)
            }
        }
    }

    func loadDeck(at url: URL) {
        do {
            let source = try DeckResolver.resolve(url: url)
            clearSecurityScopedAccess()
            activateSecurityScopedAccess(for: source)
            errorMessage = nil
            activeDeck = source
            reloadID = UUID()
        } catch {
            errorMessage = DeckResolver.message(for: error)
            if activeDeck != nil {
                activeDeck = nil
            }
        }
    }

    func handleLoadFailure(_ message: String) {
        clearSecurityScopedAccess()
        activeDeck = nil
        errorMessage = message
    }

    private func activateSecurityScopedAccess(for source: DeckSource) {
        guard case let .local(entrypointURL, readAccessURL, _) = source else {
            return
        }

        for url in [readAccessURL, entrypointURL] {
            guard activeSecurityScopedURLs.contains(url) == false else {
                continue
            }

            if url.startAccessingSecurityScopedResource() {
                activeSecurityScopedURLs.append(url)
            }
        }
    }

    private func clearSecurityScopedAccess() {
        for url in activeSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }

        activeSecurityScopedURLs.removeAll()
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: GrandRevealModel

    var body: some View {
        Group {
            if let activeDeck = model.activeDeck {
                PresentationView(
                    deck: activeDeck,
                    reloadID: model.reloadID,
                    onLoadFailure: model.handleLoadFailure
                )
            } else {
                LaunchPadView(
                    errorMessage: model.errorMessage,
                    onOpenDeck: model.openDeckPicker,
                    onLoadDemo: model.loadDemo,
                    onDropDeck: model.loadDeck
                )
            }
        }
        .background(WindowAccessorView())
        .frame(minWidth: 1280, minHeight: 720)
        .background(Color.black.opacity(0.95))
    }
}

private struct PresentationView: View {
    let deck: DeckSource
    let reloadID: UUID
    let onLoadFailure: (String) -> Void

    var body: some View {
        RevealWebView(
            source: deck,
            reloadID: reloadID,
            onLoadFailure: onLoadFailure
        )
        .ignoresSafeArea()
    }
}

private struct LaunchPadView: View {
    let errorMessage: String?
    let onOpenDeck: () -> Void
    let onLoadDemo: () -> Void
    let onDropDeck: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.12),
                    Color(red: 0.12, green: 0.07, blue: 0.04),
                    Color(red: 0.03, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Text("GrandReveal")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Load a Reveal.js deck or open the bundled demo.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 22) {
                    LaunchTile(
                        title: "Open Deck",
                        subtitle: "Drop a folder or HTML entrypoint",
                        icon: "square.and.arrow.down",
                        action: onOpenDeck
                    )

                    LaunchTile(
                        title: "Load Demo",
                        subtitle: "Open the bundled Reveal.js demo deck",
                        icon: "sparkles.rectangle.stack",
                        action: onLoadDemo
                    )
                }
                .padding(.top, 12)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(34)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(isTargeted ? .orange.opacity(0.9) : .white.opacity(0.08), lineWidth: 2)
                    )
            )
            .padding(40)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else {
                return false
            }

            Task {
                if let url = await provider.loadFileURL() {
                    await MainActor.run {
                        onDropDeck(url)
                    }
                }
            }

            return true
        }
    }
}

private struct LaunchTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 82, height: 82)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.black.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private extension NSItemProvider {
    func loadFileURL() async -> URL? {
        await withCheckedContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
            }
        }
    }
}

private struct WindowAccessorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowAccessorNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowAccessorNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindowIfNeeded()
    }

    override func layout() {
        super.layout()
        configureWindowIfNeeded()
    }

    private func configureWindowIfNeeded() {
        guard let window else {
            return
        }

        let aspectRatio = NSSize(width: 16, height: 9)
        let minimumContentSize = NSSize(width: 1280, height: 720)

        if window.contentAspectRatio != aspectRatio {
            window.contentAspectRatio = aspectRatio
        }

        if window.contentMinSize != minimumContentSize {
            window.contentMinSize = minimumContentSize
        }

        if window.contentResizeIncrements != .zero {
            window.contentResizeIncrements = .zero
        }
    }
}
