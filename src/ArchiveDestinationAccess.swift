// 2026-07-21 15:52 SGT

import Foundation

enum ArchiveDestinationAccessError: Error, Equatable, Sendable {
    case notFileURL
    case doesNotExist
    case notDirectory
    case inaccessibleDirectory
    case equalsScanRoot
    case insideScanRoot
    case scopedAccessAcquisitionFailed
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case staleBookmark
}

protocol ArchiveDestinationAccessProviding: Sendable {
    func authorize(selectedURL: URL, scanRoots: [URL]) throws -> ArchiveDestination
    func withAccess<T>(to destination: ArchiveDestination, operation: (URL) throws -> T) throws -> T
}

struct ArchiveDestinationAccess: ArchiveDestinationAccessProviding, Sendable {
    struct Environment: Sendable {
        let fileExists: @Sendable (URL) -> Bool
        let isDirectory: @Sendable (URL) throws -> Bool
        let startAccess: @Sendable (URL) -> Bool
        let stopAccess: @Sendable (URL) -> Void
        let createBookmark: @Sendable (URL) throws -> Data
        let resolveBookmark: @Sendable (Data) throws -> (url: URL, isStale: Bool)

        nonisolated static let live = Environment(
            fileExists: { FileManager.default.fileExists(atPath: $0.path) },
            isDirectory: { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true },
            startAccess: { $0.startAccessingSecurityScopedResource() },
            stopAccess: { $0.stopAccessingSecurityScopedResource() },
            createBookmark: {
                try $0.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: [.isDirectoryKey],
                    relativeTo: nil
                )
            },
            resolveBookmark: {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: $0,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return (url, isStale)
            }
        )
    }

    private let environment: Environment

    nonisolated init(environment: Environment = .live) {
        self.environment = environment
    }

    nonisolated func authorize(selectedURL: URL, scanRoots: [URL]) throws -> ArchiveDestination {
        guard selectedURL.isFileURL else { throw ArchiveDestinationAccessError.notFileURL }
        let accessed = environment.startAccess(selectedURL)
        guard accessed else { throw ArchiveDestinationAccessError.scopedAccessAcquisitionFailed }
        defer { environment.stopAccess(selectedURL) }

        let canonicalURL = ArchiveDestinationPath.canonicalURL(selectedURL)
        guard environment.fileExists(canonicalURL) else { throw ArchiveDestinationAccessError.doesNotExist }
        let isDirectory: Bool
        do {
            isDirectory = try environment.isDirectory(canonicalURL)
        } catch {
            throw ArchiveDestinationAccessError.inaccessibleDirectory
        }
        guard isDirectory else { throw ArchiveDestinationAccessError.notDirectory }

        for scanRoot in scanRoots.map(ArchiveDestinationPath.canonicalURL) {
            if canonicalURL == scanRoot { throw ArchiveDestinationAccessError.equalsScanRoot }
            if ArchiveDestinationPath.contains(canonicalURL, in: scanRoot) {
                throw ArchiveDestinationAccessError.insideScanRoot
            }
        }

        let bookmarkData: Data?
        do {
            bookmarkData = try environment.createBookmark(selectedURL)
        } catch {
            throw ArchiveDestinationAccessError.bookmarkCreationFailed
        }
        return ArchiveDestination(canonicalRootURL: canonicalURL, securityScopedBookmarkData: bookmarkData)
    }

    nonisolated func withAccess<T>(
        to destination: ArchiveDestination,
        operation: (URL) throws -> T
    ) throws -> T {
        let accessURL: URL
        if let bookmarkData = destination.securityScopedBookmarkData {
            let resolution: (url: URL, isStale: Bool)
            do {
                resolution = try environment.resolveBookmark(bookmarkData)
            } catch {
                throw ArchiveDestinationAccessError.bookmarkResolutionFailed
            }
            guard !resolution.isStale else { throw ArchiveDestinationAccessError.staleBookmark }
            accessURL = resolution.url
        } else {
            accessURL = destination.canonicalRootURL
        }

        let accessed = environment.startAccess(accessURL)
        guard accessed else { throw ArchiveDestinationAccessError.scopedAccessAcquisitionFailed }
        defer { environment.stopAccess(accessURL) }

        let canonicalURL = ArchiveDestinationPath.canonicalURL(accessURL)
        guard canonicalURL == destination.canonicalRootURL else {
            throw ArchiveDestinationAccessError.bookmarkResolutionFailed
        }
        guard environment.fileExists(canonicalURL) else { throw ArchiveDestinationAccessError.doesNotExist }
        do {
            guard try environment.isDirectory(canonicalURL) else {
                throw ArchiveDestinationAccessError.notDirectory
            }
        } catch let error as ArchiveDestinationAccessError {
            throw error
        } catch {
            throw ArchiveDestinationAccessError.inaccessibleDirectory
        }
        return try operation(canonicalURL)
    }
}
