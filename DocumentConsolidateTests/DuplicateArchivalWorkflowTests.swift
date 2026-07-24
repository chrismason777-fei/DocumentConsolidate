// 2026-07-24 21:08 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

struct DuplicateArchivalWorkflowTests {
    private let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    @MainActor
    @Test func deterministicRecommendationApprovesWithoutReselection() async {
        let group = duplicateGroup(hash: "deterministic", evidencedIndex: 0)
        let manager = configuredManager(group: group)
        let revision = manager.inventory.executionPlanDecisionRevision

        await manager.approveArchival(id: group.identifier, definitiveDocumentID: group.documents[0].id)

        #expect(manager.recommendations[0].decision == .approved)
        #expect(manager.recommendations[0].definitiveDocumentID == group.documents[0].id)
        #expect(manager.inventory.executionPlanDecisionRevision == revision + 1)
        #expect(manager.executionPlan == nil)
        #expect(manager.currentSession?.acceptedRecommendationCount == 1)
    }

    @MainActor
    @Test func manualSelectionAndApprovalAreOneAtomicMutation() async {
        let group = duplicateGroup(hash: "manual")
        let manager = configuredManager(group: group)
        let revision = manager.inventory.executionPlanDecisionRevision

        await manager.approveArchival(id: group.identifier, definitiveDocumentID: group.documents[1].id)

        #expect(manager.recommendations[0].status == .readyForApproval)
        #expect(manager.recommendations[0].decision == .approved)
        #expect(manager.recommendations[0].definitiveDocumentID == group.documents[1].id)
        #expect(manager.recommendations[0].redundantDocumentIDs == [group.documents[0].id])
        #expect(manager.inventory.executionPlanDecisionRevision == revision + 1)
    }

    @MainActor
    @Test func invalidSelectionDoesNotPartiallyChangeRecommendationOrPlan() async {
        let group = duplicateGroup(hash: "invalid")
        let manager = configuredManager(group: group)
        let recommendation = manager.recommendations[0]
        let plan = manager.executionPlan
        let revision = manager.inventory.executionPlanDecisionRevision

        await manager.approveArchival(id: group.identifier, definitiveDocumentID: UUID())

        #expect(manager.recommendations[0] == recommendation)
        #expect(manager.executionPlan == plan)
        #expect(manager.inventory.executionPlanDecisionRevision == revision)
        #expect(manager.currentSession?.acceptedRecommendationCount == 0)
    }

    @MainActor
    @Test func editingApprovedKeepSelectionRequiresFreshDecision() async {
        let group = duplicateGroup(hash: "edit")
        let manager = configuredManager(group: group)
        await manager.approveArchival(id: group.identifier, definitiveDocumentID: group.documents[0].id)

        await manager.selectDefinitiveCopy(id: group.identifier, documentID: group.documents[1].id)

        #expect(manager.recommendations[0].decision == .pending)
        #expect(manager.recommendations[0].definitiveDocumentID == group.documents[1].id)
        #expect(manager.executionPlan?.operations.isEmpty == true)
        #expect(manager.currentSession?.acceptedRecommendationCount == 0)
    }

    @Test func executionRemovesSourceAfterPostCopyHashesMatch() async throws {
        let fixture = try await executionFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let summary = try await ExecutionEngine().execute(fixture.plan, authorizedRoot: fixture.archiveRoot)

        #expect(summary.results.first?.outcome == .succeeded)
        #expect(summary.results.first?.sourceRemoved == true)
        #expect(!FileManager.default.fileExists(atPath: fixture.source.path))
        #expect(FileManager.default.fileExists(atPath: fixture.destination.path))
    }

    @Test func postValidationSourceChangeProducesFreshHashMismatchAndPreservesSource() async throws {
        let fixture = try await executionFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let fileManager = CopyMutatingFileManager { source, _ in
            try Data("changed source".utf8).write(to: source)
        }

        let summary = try await ExecutionEngine(fileManager: fileManager)
            .execute(fixture.plan, authorizedRoot: fixture.archiveRoot)

        #expect(summary.results.first?.outcome == .failed)
        #expect(summary.results.first?.sourceRemoved == false)
        #expect(FileManager.default.fileExists(atPath: fixture.source.path))
    }

    @Test func archiveHashMismatchFailsAndPreservesSource() async throws {
        let fixture = try await executionFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let fileManager = CopyMutatingFileManager { _, destination in
            try Data("changed archive".utf8).write(to: destination)
        }

        let summary = try await ExecutionEngine(fileManager: fileManager)
            .execute(fixture.plan, authorizedRoot: fixture.archiveRoot)

        #expect(summary.results.first?.outcome == .failed)
        #expect(summary.results.first?.sourceRemoved == false)
        #expect(FileManager.default.fileExists(atPath: fixture.source.path))
    }

    @MainActor
    private func configuredManager(group: DuplicateGroup) -> ScanManager {
        let inventory = Inventory()
        let manager = ScanManager(inventory: inventory)
        _ = manager.createSession()
        inventory.replace(with: group.documents)
        inventory.replaceRecommendations(with: RecommendationService().generate(from: [group]).recommendations)
        manager.refreshRecommendationSummary()
        return manager
    }

    private func duplicateGroup(hash: String, evidencedIndex: Int? = nil) -> DuplicateGroup {
        let documents = (0..<2).map { index in
            DocumentRecord(
                id: UUID(uuidString: String(format: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAA%02d", index))!,
                scanSessionID: sessionID,
                url: URL(filePath: "/fixtures/duplicate-\(index).txt"),
                filename: "duplicate-\(index).txt",
                fileExtension: "txt",
                fileSize: 22,
                createdAt: nil,
                modifiedAt: nil,
                analysisStatus: .complete,
                isSupported: true,
                category: .text,
                contentHash: hash,
                hashStatus: .complete,
                duplicateStatus: .duplicate,
                duplicateGroupIdentifier: hash,
                duplicateGroupSize: 2,
                hasApprovedDefinitiveCopyEvidence: evidencedIndex == index
            )
        }
        return DuplicateGroup(identifier: hash, documents: documents)
    }

    private func executionFixture() async throws -> (
        root: URL,
        archiveRoot: URL,
        source: URL,
        destination: URL,
        plan: ExecutionPlan
    ) {
        let root = FileManager.default.temporaryDirectory.appending(path: "ExecutionEngine-\(UUID().uuidString)")
        let source = root.appending(path: "source.txt")
        let definitive = root.appending(path: "definitive.txt")
        let archiveRoot = root.appending(path: "archive", directoryHint: .isDirectory)
        let destination = archiveRoot.appending(path: "session/source.txt")
        let content = Data("approved duplicate".utf8)
        try FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        try content.write(to: source)
        try content.write(to: definitive)
        let hash = try await DocumentContentHasher.hash(fileAt: source)
        let sourceRecord = document(at: source, size: Int64(content.count), hash: hash)
        let definitiveRecord = document(at: definitive, size: Int64(content.count), hash: hash)
        let operation = PlannedOperation(
            id: "operation",
            type: .archiveRedundantCopy,
            sourceDocument: sourceRecord,
            destination: destination,
            definitiveDocument: definitiveRecord,
            reason: "Test",
            recommendationID: "recommendation",
            expectedHash: hash,
            expectedDefinitiveHash: hash,
            executionStatus: .notStarted,
            validationStatus: .valid,
            validationIssues: []
        )
        return (
            root,
            archiveRoot,
            source,
            destination,
            ExecutionPlan(
                id: "plan",
                scanSessionID: sessionID,
                operations: [operation],
                destinationRoot: archiveRoot
            )
        )
    }

    private func document(at url: URL, size: Int64, hash: String) -> DocumentRecord {
        DocumentRecord(
            scanSessionID: sessionID,
            url: url,
            filename: url.lastPathComponent,
            fileExtension: url.pathExtension,
            fileSize: size,
            createdAt: nil,
            modifiedAt: nil,
            analysisStatus: .complete,
            isSupported: true,
            category: .text,
            contentHash: hash,
            hashStatus: .complete,
            duplicateStatus: .duplicate,
            duplicateGroupIdentifier: hash,
            duplicateGroupSize: 2
        )
    }
}

private final class CopyMutatingFileManager: FileManager, @unchecked Sendable {
    private let mutateAfterCopy: (URL, URL) throws -> Void

    init(mutateAfterCopy: @escaping (URL, URL) throws -> Void) {
        self.mutateAfterCopy = mutateAfterCopy
        super.init()
    }

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try super.copyItem(at: srcURL, to: dstURL)
        try mutateAfterCopy(srcURL, dstURL)
    }
}
