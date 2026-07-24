// 2026-07-24 16:23 SGT

import Foundation

enum ArchiveDestinationAccessError: Error, Equatable, Sendable {
    case notFileURL
    case doesNotExist
    case notDirectory
    case inaccessibleDirectory
    case notWritable
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
        let verifyWritable: @Sendable (URL) throws -> Void

        init(
            fileExists: @escaping @Sendable (URL) -> Bool,
            isDirectory: @escaping @Sendable (URL) throws -> Bool,
            startAccess: @escaping @Sendable (URL) -> Bool,
            stopAccess: @escaping @Sendable (URL) -> Void,
            createBookmark: @escaping @Sendable (URL) throws -> Data,
            resolveBookmark: @escaping @Sendable (Data) throws -> (url: URL, isStale: Bool),
            verifyWritable: @escaping @Sendable (URL) throws -> Void = { _ in }
        ) {
            self.fileExists = fileExists
            self.isDirectory = isDirectory
            self.startAccess = startAccess
            self.stopAccess = stopAccess
            self.createBookmark = createBookmark
            self.resolveBookmark = resolveBookmark
            self.verifyWritable = verifyWritable
        }

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
            },
            verifyWritable: { root in
                let probe = root.appending(
                    path: ".document-consolidate-write-probe-\(UUID().uuidString)",
                    directoryHint: .isDirectory
                )
                defer { try? FileManager.default.removeItem(at: probe) }
                try FileManager.default.createDirectory(at: probe, withIntermediateDirectories: false)
                try FileManager.default.removeItem(at: probe)
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
        try verifyWritable(canonicalURL)

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
        try verifyWritable(canonicalURL)
        return try operation(canonicalURL)
    }

    nonisolated func withAccess<T: Sendable>(
        to destination: ArchiveDestination,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let accessURL = try resolvedAccessURL(for: destination)
        let accessed = environment.startAccess(accessURL)
        guard accessed else { throw ArchiveDestinationAccessError.scopedAccessAcquisitionFailed }
        defer { environment.stopAccess(accessURL) }
        let canonicalURL = try validateAccessURL(accessURL, destination: destination)
        return try await operation(canonicalURL)
    }

    private nonisolated func resolvedAccessURL(
        for destination: ArchiveDestination
    ) throws -> URL {
        if let bookmarkData = destination.securityScopedBookmarkData {
            let resolution: (url: URL, isStale: Bool)
            do {
                resolution = try environment.resolveBookmark(bookmarkData)
            } catch {
                throw ArchiveDestinationAccessError.bookmarkResolutionFailed
            }
            guard !resolution.isStale else { throw ArchiveDestinationAccessError.staleBookmark }
            return resolution.url
        }
        return destination.canonicalRootURL
    }

    private nonisolated func validateAccessURL(
        _ accessURL: URL,
        destination: ArchiveDestination
    ) throws -> URL {
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
        try verifyWritable(canonicalURL)
        return canonicalURL
    }

    private nonisolated func verifyWritable(_ url: URL) throws {
        do {
            try environment.verifyWritable(url)
        } catch {
            throw ArchiveDestinationAccessError.notWritable
        }
    }
}
