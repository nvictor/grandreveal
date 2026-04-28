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
            NSDocumentController.shared.noteNewRecentDocumentURL(source.recentDocumentURL)
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
        guard case let .local(entrypointURL, readAccessURL, _, _) = source else {
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

private struct GrandRevealFocusedModelKey: FocusedValueKey {
    typealias Value = GrandRevealModel
}

extension FocusedValues {
    var grandRevealFocusedModel: GrandRevealModel? {
        get { self[GrandRevealFocusedModelKey.self] }
        set { self[GrandRevealFocusedModelKey.self] = newValue }
    }
}

struct GrandRevealWindowRootView: View {
    @StateObject private var model = GrandRevealModel()

    var body: some View {
        ContentView()
            .environmentObject(model)
            .focusedSceneValue(\.grandRevealFocusedModel, model)
            .onAppear {
                RecentDeckCoordinator.shared.register(model)
            }
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
                    onDropDeck: model.loadDeck
                )
            }
        }
        .background(WindowAccessorView())
        .frame(minWidth: 960, minHeight: 540)
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
    let onDropDeck: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.11)
                .ignoresSafeArea()

            ContentUnavailableView {
                Text("GrandReveal")
            } description: {
                Text("Load a Reveal.js deck folder or HTML entrypoint.")
            } actions: {
                Button("Open Deck", action: onOpenDeck)
                    .buttonStyle(.borderedProminent)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white, .white.opacity(0.72))
            .padding(40)
            .background(isTargeted ? Color.white.opacity(0.04) : .clear)
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
        let minimumContentSize = NSSize(width: 960, height: 540)

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
