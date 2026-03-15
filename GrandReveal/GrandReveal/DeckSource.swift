//
//  DeckSource.swift
//  GrandReveal
//
//  Created by Codex on 3/15/26.
//

import Foundation

struct DeckLoadContext {
    let entrypointURL: URL
    let readAccessURL: URL
}

enum DeckSource: Equatable {
    case bundledDemo
    case local(entrypointURL: URL, readAccessURL: URL, displayName: String)

    var title: String {
        switch self {
        case .bundledDemo:
            return "Reveal.js Demo"
        case let .local(_, _, displayName):
            return displayName
        }
    }

    func makeLoadContext(bundle: Bundle = .main) throws -> DeckLoadContext {
        switch self {
        case .bundledDemo:
            guard let entrypointURL = bundle.url(forResource: "demo", withExtension: "html"),
                  let readAccessURL = bundle.resourceURL
            else {
                throw DeckSourceError.bundledDemoMissing
            }

            return DeckLoadContext(entrypointURL: entrypointURL, readAccessURL: readAccessURL)

        case let .local(entrypointURL, readAccessURL, _):
            return DeckLoadContext(entrypointURL: entrypointURL, readAccessURL: readAccessURL)
        }
    }
}

enum DeckSourceError: LocalizedError {
    case bundledDemoMissing

    var errorDescription: String? {
        switch self {
        case .bundledDemoMissing:
            return "The bundled Reveal.js demo could not be found in the app bundle."
        }
    }
}
