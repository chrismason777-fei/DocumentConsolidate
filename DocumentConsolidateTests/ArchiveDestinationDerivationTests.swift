// 2026-07-21 17:31 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

@MainActor
struct ArchiveDestinationDerivationTests {
    private let sessionID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let createdAt = Date(timeIntervalSince1970: 1_774_070_400)

    @Test func serviceDerivesDeterministicHierarchyAndMetadata() throws {
        try withFixture { fixture in
            let source = fixture.scanRoot.appending(path: "Team/Reports/report.txt")
            let definitive = document(id: 1, url: fixture.scanRoot.appending(path: "original.txt"))
            let redundant = document(id: 2, url: source)
            let recommendation = approvedRecommendation(definitive: definitive, redundant: redundant)

            let first = makeService().generate(
                recommendations: [recommendation],
                documents: [definitive, redundant],
                scanRoots: [fixture.scanRoot],
                archiveDestination: fixture.destination,
                scanSessionID: sessionID,
                decisionRevision: 7,
                createdAt: createdAt,
                calendar: utcCalendar
            )
            let second = makeService().generate(
                recommendations: [recommendation],
                documents: [definitive, redundant],
                scanRoots: [fixture.scanRoot],
                archiveDestination: fixture.destination,
                scanSessionID: sessionID,
                decisionRevision: 7,
                createdAt: createdAt,
                calendar: utcCalendar
            )

            #expect(first == second)
            #expect(first.destinationRoot == fixture.destination.canonicalRootURL)
            #expect(first.decisionRevision == 7)
            #expect(first.createdAt == createdAt)
            #expect(first.operations[0].destination?.path.hasSuffix("/Team/Reports/report.txt") == true)
            #expect(first.operations[0].destination?.pathComponents.contains("2026-03-21 0520 – 111111") == true)
        }
    }

    @Test func longestRootWinsAndRootIdentifiersAreStable() throws {
        try withFixture { fixture in
            let nestedRoot = fixture.scanRoot.appending(path: "Nested", directoryHint: .isDirectory)
            let source = nestedRoot.appending(path: "file.txt")
            let deriver = makeDeriver()
            let result = deriver.derive(
                operations: [operation(id: "one", source: source)],
                scanRoots: [fixture.scanRoot, nestedRoot],
                destination: fixture.destination,
                sessionID: sessionID,
                createdAt: createdAt,
                calendar: utcCalendar
            )[0]

            #expect(result.destination?.pathComponents.suffix(2) == [deriver.rootIdentifier(for: nestedRoot), "file.txt"])
            #expect(deriver.rootIdentifier(for: nestedRoot) == deriver.rootIdentifier(for: nestedRoot.standardizedFileURL))
            #expect(deriver.rootIdentifier(for: nestedRoot) != deriver.rootIdentifier(for: fixture.scanRoot))
        }
    }

    @Test func duplicateDestinationsAreTypedBlockingIssues() throws {
        try withFixture { fixture in
            let source = fixture.scanRoot.appending(path: "same.txt")
            let results = derive(
                [operation(id: "one", source: source), operation(id: "two", source: source)],
                fixture: fixture
            )

            #expect(results.allSatisfy { $0.validationStatus == .invalid })
            #expect(results.allSatisfy { operation in
                operation.destinationDerivationIssues.contains {
                    if case .duplicateDestination = $0 { return true }
                    return false
                }
            })
        }
    }

    @Test func existingDestinationIsDetectedWithoutRepair() throws {
        try withFixture { fixture in
            let source = fixture.scanRoot.appending(path: "existing.txt")
            let initial = derive([operation(id: "one", source: source)], fixture: fixture)[0]
            let destination = try #require(initial.destination)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("occupied".utf8).write(to: destination)

            let result = ArchiveDestinationDerivation().derive(
                operations: [operation(id: "one", source: source)],
                scanRoots: [fixture.scanRoot],
                destination: fixture.destination,
                sessionID: sessionID,
                createdAt: createdAt,
                calendar: utcCalendar
            )[0]

            #expect(result.destinationDerivationIssues.contains(.destinationAlreadyExists(destination)))
        }
    }

    @Test func symbolicLinkEscapeAndSourceEqualityAreDetected() throws {
        try withFixture { fixture in
            let deriver = makeDeriver()
            let source = fixture.scanRoot.appending(path: "escape.txt")
            let rootIdentifier = deriver.rootIdentifier(for: fixture.scanRoot)
            let sessionRoot = fixture.destination.canonicalRootURL
                .appending(path: "Document Consolidate")
                .appending(path: deriver.sessionDirectoryName(sessionID: sessionID, createdAt: createdAt, calendar: utcCalendar))
            try FileManager.default.createDirectory(at: sessionRoot, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(
                at: sessionRoot.appending(path: rootIdentifier),
                withDestinationURL: fixture.scanRoot
            )
            try Data("source".utf8).write(to: source)

            let result = deriver.derive(
                operations: [operation(id: "one", source: source)],
                scanRoots: [fixture.scanRoot],
                destination: fixture.destination,
                sessionID: sessionID,
                createdAt: createdAt,
                calendar: utcCalendar
            )[0]

            #expect(result.destinationDerivationIssues.contains(.destinationEscapesRoot))
            #expect(result.destinationDerivationIssues.contains(.sourceEqualsDestination(source)))
        }
    }

    @Test func sourceOutsideRootsIsRejectedAndDerivationDoesNotMutateFilesystem() throws {
        try withFixture { fixture in
            let before = try directoryContents(fixture.root)
            let result = derive(
                [operation(id: "one", source: fixture.root.appending(path: "outside.txt"))],
                fixture: fixture
            )[0]
            let after = try directoryContents(fixture.root)

            #expect(result.destination == nil)
            #expect(result.destinationDerivationIssues == [.sourceOutsideScanRoots])
            #expect(before == after)
        }
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeService() -> ExecutionPlanService {
        ExecutionPlanService(destinationDerivation: makeDeriver())
    }

    private func makeDeriver() -> ArchiveDestinationDerivation {
        ArchiveDestinationDerivation(environment: .init(itemExists: { _ in false }))
    }

    private func derive(_ operations: [PlannedOperation], fixture: Fixture) -> [PlannedOperation] {
        makeDeriver().derive(
            operations: operations,
            scanRoots: [fixture.scanRoot],
            destination: fixture.destination,
            sessionID: sessionID,
            createdAt: createdAt,
            calendar: utcCalendar
        )
    }

    private func operation(id: String, source: URL) -> PlannedOperation {
        let sourceDocument = document(id: id == "one" ? 1 : 2, url: source)
        return PlannedOperation(
            id: id,
            type: .archiveRedundantCopy,
            sourceDocument: sourceDocument,
            destination: nil,
            definitiveDocument: document(id: 9, url: source.deletingLastPathComponent().appending(path: "definitive.txt")),
            reason: "Test",
            recommendationID: "hash",
            expectedHash: "hash",
            expectedDefinitiveHash: "hash",
            executionStatus: .notStarted,
            validationStatus: .pending,
            validationIssues: []
        )
    }

    private func document(id: Int, url: URL) -> DocumentRecord {
        DocumentRecord(
            id: UUID(uuidString: String(format: "AAAAAAAA-AAAA-AAAA-AAAA-%012d", id))!,
            scanSessionID: sessionID,
            url: url,
            filename: url.lastPathComponent,
            fileExtension: "txt",
            fileSize: 1,
            createdAt: nil,
            modifiedAt: nil,
            contentHash: "hash"
        )
    }

    private func approvedRecommendation(
        definitive: DocumentRecord,
        redundant: DocumentRecord
    ) -> DuplicateRecommendation {
        DuplicateRecommendation(
            id: "hash",
            duplicateGroupIdentifier: "hash",
            definitiveDocumentID: definitive.id,
            redundantDocumentIDs: [redundant.id],
            status: .readyForApproval,
            rationale: "Test",
            isDeterministic: true,
            decision: .approved
        )
    }

    private func directoryContents(_ root: URL) throws -> [String] {
        try FileManager.default.subpathsOfDirectory(atPath: root.path).sorted()
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "ArchiveDerivation-\(UUID().uuidString)")
        let scanRoot = root.appending(path: "Scan", directoryHint: .isDirectory)
        let destinationURL = root.appending(path: "Archive", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: scanRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(Fixture(root: root, scanRoot: scanRoot, destination: ArchiveDestination(canonicalRootURL: destinationURL, securityScopedBookmarkData: nil)))
    }

    private struct Fixture {
        let root: URL
        let scanRoot: URL
        let destination: ArchiveDestination
    }
}
