// 2026-07-21 15:52 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

struct ArchiveDestinationAuthorizationTests {
    @Test func canonicalEqualityIgnoresEquivalentSyntaxAndBookmarkBytes() throws {
        try withFixture { fixture in
            let first = ArchiveDestination(
                canonicalRootURL: fixture.destination.appending(path: "Folder").deletingLastPathComponent(),
                securityScopedBookmarkData: Data([1])
            )
            let second = ArchiveDestination(
                canonicalRootURL: fixture.destination,
                securityScopedBookmarkData: Data([2])
            )
            #expect(first == second)
            #expect(Set([first, second]).count == 1)
        }
    }

    @Test func existingDirectoryIsAccepted() throws {
        try withFixture { fixture in
            let access = testAccess()
            let destination = try access.authorize(selectedURL: fixture.destination, scanRoots: [fixture.scanRoot])
            #expect(destination.canonicalRootURL == ArchiveDestinationPath.canonicalURL(fixture.destination))
            #expect(destination.securityScopedBookmarkData == Data("bookmark".utf8))
        }
    }

    @Test func invalidKindsReturnTypedErrors() throws {
        try withFixture { fixture in
            let missing = fixture.root.appending(path: "Missing")
            #expect(throws: ArchiveDestinationAccessError.doesNotExist) {
                try testAccess().authorize(selectedURL: missing, scanRoots: [])
            }
            #expect(throws: ArchiveDestinationAccessError.notDirectory) {
                try testAccess().authorize(selectedURL: fixture.file, scanRoots: [])
            }
            #expect(throws: ArchiveDestinationAccessError.notFileURL) {
                try testAccess().authorize(selectedURL: URL(string: "https://example.com")!, scanRoots: [])
            }
        }
    }

    @Test func equalNestedAndMultipleRootsAreRejected() throws {
        try withFixture { fixture in
            let nested = fixture.scanRoot.appending(path: "Nested", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            #expect(throws: ArchiveDestinationAccessError.equalsScanRoot) {
                try testAccess().authorize(selectedURL: fixture.scanRoot, scanRoots: [fixture.scanRoot])
            }
            #expect(throws: ArchiveDestinationAccessError.insideScanRoot) {
                try testAccess().authorize(selectedURL: nested, scanRoots: [fixture.destination, fixture.scanRoot])
            }
        }
    }

    @Test func componentAwareContainmentAcceptsSimilarSibling() throws {
        try withFixture { fixture in
            let sibling = fixture.root.appending(path: "Scan Old", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
            #expect(throws: Never.self) {
                try testAccess().authorize(selectedURL: sibling, scanRoots: [fixture.scanRoot])
            }
        }
    }

    @Test func symbolicLinkCannotBypassContainment() throws {
        try withFixture { fixture in
            let nested = fixture.scanRoot.appending(path: "Nested", directoryHint: .isDirectory)
            let link = fixture.root.appending(path: "Alias", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: nested)
            #expect(throws: ArchiveDestinationAccessError.insideScanRoot) {
                try testAccess().authorize(selectedURL: link, scanRoots: [fixture.scanRoot])
            }
        }
    }

    @Test func scopeAndBookmarkFailuresAreDistinct() throws {
        try withFixture { fixture in
            #expect(throws: ArchiveDestinationAccessError.scopedAccessAcquisitionFailed) {
                try testAccess(startAccess: { _ in false }).authorize(selectedURL: fixture.destination, scanRoots: [])
            }
            #expect(throws: ArchiveDestinationAccessError.bookmarkCreationFailed) {
                try testAccess(createBookmark: { _ in throw FixtureError.expected })
                    .authorize(selectedURL: fixture.destination, scanRoots: [])
            }
        }
    }

    @Test func auditedBookmarkPolicyRequiresBookmarkCreation() throws {
        try withFixture { fixture in
            let required = testAccess(createBookmark: { _ in throw FixtureError.expected })
            #expect(throws: ArchiveDestinationAccessError.bookmarkCreationFailed) {
                try required.authorize(selectedURL: fixture.destination, scanRoots: [])
            }
        }
    }

    @Test func staleAndFailedBookmarkResolutionAreDistinct() throws {
        try withFixture { fixture in
            let destination = ArchiveDestination(
                canonicalRootURL: fixture.destination,
                securityScopedBookmarkData: Data("bookmark".utf8)
            )
            #expect(throws: ArchiveDestinationAccessError.staleBookmark) {
                try testAccess(resolveBookmark: { _ in (fixture.destination, true) })
                    .withAccess(to: destination) { _ in }
            }
            #expect(throws: ArchiveDestinationAccessError.bookmarkResolutionFailed) {
                try testAccess(resolveBookmark: { _ in throw FixtureError.expected })
                    .withAccess(to: destination) { _ in }
            }
        }
    }

    @Test func temporaryAccessAlwaysStops() throws {
        try withFixture { fixture in
            let counter = AccessCounter()
            let destination = ArchiveDestination(
                canonicalRootURL: fixture.destination,
                securityScopedBookmarkData: Data("bookmark".utf8)
            )
            let access = testAccess(
                stopAccess: { _ in counter.stops += 1 },
                resolveBookmark: { _ in (fixture.destination, false) }
            )
            #expect(throws: FixtureError.expected) {
                try access.withAccess(to: destination) { _ in throw FixtureError.expected }
            }
            #expect(counter.stops == 1)
        }
    }

    private func testAccess(
        startAccess: @escaping @Sendable (URL) -> Bool = { _ in true },
        stopAccess: @escaping @Sendable (URL) -> Void = { _ in },
        createBookmark: @escaping @Sendable (URL) throws -> Data = { _ in Data("bookmark".utf8) },
        resolveBookmark: @escaping @Sendable (Data) throws -> (url: URL, isStale: Bool) = { _ in throw FixtureError.expected }
    ) -> ArchiveDestinationAccess {
        ArchiveDestinationAccess(
            environment: .init(
                fileExists: { FileManager.default.fileExists(atPath: $0.path) },
                isDirectory: { try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true },
                startAccess: startAccess,
                stopAccess: stopAccess,
                createBookmark: createBookmark,
                resolveBookmark: resolveBookmark
            )
        )
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "DocumentConsolidate-Authorization-\(UUID().uuidString)", directoryHint: .isDirectory)
        let scanRoot = root.appending(path: "Scan", directoryHint: .isDirectory)
        let destination = root.appending(path: "Archive", directoryHint: .isDirectory)
        let file = root.appending(path: "file.txt")
        try FileManager.default.createDirectory(at: scanRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(Fixture(root: root, scanRoot: scanRoot, destination: destination, file: file))
    }

    private struct Fixture {
        let root: URL
        let scanRoot: URL
        let destination: URL
        let file: URL
    }

    private final class AccessCounter: @unchecked Sendable {
        var stops = 0
    }

    private enum FixtureError: Error {
        case expected
    }
}
