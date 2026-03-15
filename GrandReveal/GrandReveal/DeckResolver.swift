//
//  DeckResolver.swift
//  GrandReveal
//
//  Created by Codex on 3/15/26.
//

import Foundation

enum DeckResolver {
    static func resolve(url: URL) throws -> DeckSource {
        let normalizedURL = url.standardizedFileURL
        let values = try normalizedURL.resourceValues(forKeys: [.isDirectoryKey])

        if values.isDirectory == true {
            return try resolveDirectory(url: normalizedURL)
        }

        return try resolveFile(url: normalizedURL)
    }

    static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }

        return "GrandReveal could not load that deck."
    }

    private static func resolveDirectory(url: URL) throws -> DeckSource {
        let candidateNames = ["index.html", "demo.html"]

        for candidateName in candidateNames {
            let candidateURL = url.appending(path: candidateName)
            if FileManager.default.fileExists(atPath: candidateURL.path()) {
                return .local(
                    entrypointURL: candidateURL,
                    readAccessURL: url,
                    displayName: url.lastPathComponent
                )
            }
        }

        let rootHTMLFiles = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { fileURL in
            ["html", "htm"].contains(fileURL.pathExtension.lowercased())
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if rootHTMLFiles.count == 1, let entrypointURL = rootHTMLFiles.first {
            return .local(
                entrypointURL: entrypointURL,
                readAccessURL: url,
                displayName: url.lastPathComponent
            )
        }

        throw DeckResolverError.directoryHasNoEntrypoint
    }

    private static func resolveFile(url: URL) throws -> DeckSource {
        let fileExtension = url.pathExtension.lowercased()
        guard ["html", "htm"].contains(fileExtension) else {
            throw DeckResolverError.unsupportedFileType
        }

        return .local(
            entrypointURL: url,
            readAccessURL: url.deletingLastPathComponent(),
            displayName: url.lastPathComponent
        )
    }
}

enum DeckResolverError: LocalizedError {
    case unsupportedFileType
    case directoryHasNoEntrypoint

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Drop a Reveal.js deck folder or an HTML entrypoint such as index.html or demo.html."
        case .directoryHasNoEntrypoint:
            return "That folder does not contain a Reveal.js HTML entrypoint."
        }
    }
}
