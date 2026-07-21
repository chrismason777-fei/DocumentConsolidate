// 2026-07-21 15:52 SGT

import Foundation

struct ArchiveDestination: Hashable, Sendable {
    let canonicalRootURL: URL
    let securityScopedBookmarkData: Data?

    nonisolated init(canonicalRootURL: URL, securityScopedBookmarkData: Data?) {
        self.canonicalRootURL = ArchiveDestinationPath.canonicalURL(canonicalRootURL)
        self.securityScopedBookmarkData = securityScopedBookmarkData
    }

    nonisolated var displayPath: String { canonicalRootURL.path(percentEncoded: false) }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.canonicalRootURL == rhs.canonicalRootURL
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(canonicalRootURL)
    }
}

enum ArchiveDestinationPath {
    nonisolated static func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    nonisolated static func contains(_ candidate: URL, in root: URL) -> Bool {
        let candidateComponents = canonicalURL(candidate).pathComponents
        let rootComponents = canonicalURL(root).pathComponents
        return candidateComponents.count >= rootComponents.count
            && Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}
