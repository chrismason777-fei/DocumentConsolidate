// 2026-07-21 11:28 SGT

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
        #expect(manager.executionPlan?.operations.count == 1)
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
}
