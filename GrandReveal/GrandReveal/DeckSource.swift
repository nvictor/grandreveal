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
    case local(entrypointURL: URL, readAccessURL: URL, displayName: String, recentDocumentURL: URL)

    var title: String {
        switch self {
        case let .local(_, _, displayName, _):
            return displayName
        }
    }

    var recentDocumentURL: URL {
        switch self {
        case let .local(_, _, _, recentDocumentURL):
            return recentDocumentURL
        }
    }

    func makeLoadContext(bundle: Bundle = .main) throws -> DeckLoadContext {
        switch self {
        case let .local(entrypointURL, readAccessURL, _, _):
            return DeckLoadContext(entrypointURL: entrypointURL, readAccessURL: readAccessURL)
        }
    }
}
