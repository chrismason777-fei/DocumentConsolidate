// 2026-07-21 11:28 SGT
//
//  DocumentConsolidateTests.swift
//  DocumentConsolidateTests
//
//  Created by Hei Long Xia on 18/7/26.
//

import Foundation
import Testing
@testable import DocumentConsolidate

struct DocumentConsolidateTests {
    private let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    @Test func exactDuplicatesGroupWhileUniqueFilesRemainUnplanned() {
        let documents = [
            record(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA1", name: "GroupA-original.txt", hash: "hash-a"),
            record(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAA2", name: "GroupA-copy.txt", hash: "hash-a"),
            record(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBB1", name: "unique.txt", hash: "hash-unique")
        ]

        let duplicateResult = DuplicateDetectionService().analyse(documents)
        let generation = RecommendationService().generate(from: duplicateResult.duplicateGroups)
        let plan = ExecutionPlanService().generate(
            recommendations: generation.recommendations,
            documents: duplicateResult.documents,
            scanSessionID: sessionID
        )

        #expect(duplicateResult.duplicateGroups.count == 1)
        #expect(duplicateResult.uniqueDocumentCount == 1)
        #expect(generation.recommendations.count == 1)
        #expect(generation.recommendations.first?.duplicateGroupIdentifier == "hash-a")
        #expect(plan.operations.isEmpty)
    }

    @MainActor
    @Test func missingApprovedEvidenceRequiresStableDefinitiveSelection() {
        let firstInput = duplicateGroup(hash: "stable-hash")
        let secondInput = DuplicateGroup(identifier: firstInput.identifier, documents: firstInput.documents.reversed())

        let first = RecommendationService().generate(from: [firstInput]).recommendations
        let second = RecommendationService().generate(from: [secondInput]).recommendations

        #expect(first == second)
        #expect(first.first?.status == .needsSelection)
        #expect(first.first?.definitiveDocumentID == nil)
        #expect(first.first?.redundantDocumentIDs.isEmpty == true)
        #expect(first.first?.decision == .pending)
    }

    @Test func controlledApprovedEvidenceProposesOneDefinitiveCopy() {
        let group = duplicateGroup(hash: "evidenced-hash", evidencedIndex: 0)
        let proposal = RecommendationService().generate(from: [group]).recommendations.first

        #expect(proposal?.status == .readyForApproval)
        #expect(proposal?.definitiveDocumentID == group.documents[0].id)
        #expect(proposal?.redundantDocumentIDs == [group.documents[1].id])
        #expect(proposal?.decision == .pending)
    }

    @MainActor
    @Test func manualSelectionAssignsEveryOtherCopyAndResetsApproval() {
        let group = duplicateGroup(hash: "manual-hash", count: 3)
        let proposal = RecommendationService().generate(from: [group]).recommendations[0]
        let inventory = Inventory()
        inventory.replaceRecommendations(with: [proposal])

        #expect(inventory.selectDefinitiveCopy(
            id: proposal.id,
            documentID: group.documents[0].id,
            groupDocumentIDs: group.documents.map(\.id)
        ))
        #expect(inventory.recommendations[0].definitiveDocumentID == group.documents[0].id)
        #expect(Set(inventory.recommendations[0].redundantDocumentIDs) == Set(group.documents.dropFirst().map(\.id)))
        #expect(inventory.recommendations[0].decision == .pending)

        #expect(inventory.updateRecommendationDecision(id: proposal.id, decision: .approved))
        #expect(inventory.selectDefinitiveCopy(
            id: proposal.id,
            documentID: group.documents[1].id,
            groupDocumentIDs: group.documents.map(\.id)
        ))
        #expect(inventory.recommendations[0].decision == .pending)
        #expect(inventory.recommendations[0].definitiveDocumentID == group.documents[1].id)
    }

    @MainActor
    @Test func onlyApprovedReadyGroupsEnterArchivePlan() {
        let group = duplicateGroup(hash: "plan-hash")
        let base = RecommendationService().generate(from: [group]).recommendations[0]
        let inventory = Inventory()
        inventory.replaceRecommendations(with: [base])
        #expect(!inventory.updateRecommendationDecision(id: base.id, decision: .approved))

        #expect(inventory.selectDefinitiveCopy(
            id: base.id,
            documentID: group.documents[0].id,
            groupDocumentIDs: group.documents.map(\.id)
        ))
        #expect(inventory.updateRecommendationDecision(id: base.id, decision: .approved))
        var plan = ExecutionPlanService().generate(
            recommendations: inventory.recommendations,
            documents: group.documents,
            scanSessionID: sessionID
        )
        #expect(plan.operations.count == 1)
        #expect(plan.operations[0].type == .archiveRedundantCopy)
        #expect(plan.operations[0].definitiveDocument.id == group.documents[0].id)
        #expect(plan.operations[0].sourceDocument?.id == group.documents[1].id)
        #expect(plan.operations[0].destination == nil)

        #expect(inventory.updateRecommendationDecision(id: base.id, decision: .rejected))
        plan = ExecutionPlanService().generate(recommendations: inventory.recommendations, documents: group.documents, scanSessionID: sessionID)
        #expect(plan.operations.isEmpty)

        #expect(inventory.updateRecommendationDecision(id: base.id, decision: .postponed))
        plan = ExecutionPlanService().generate(recommendations: inventory.recommendations, documents: group.documents, scanSessionID: sessionID)
        #expect(plan.operations.isEmpty)
    }

    @MainActor
    @Test func selectionApprovalAndPlanReviewDoNotModifySources() async throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DocumentConsolidate-Safety-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        let definitiveURL = testDirectory.appending(path: "original.txt")
        let redundantURL = testDirectory.appending(path: "copy.txt")
        let bytes = Data("byte-identical fixture".utf8)
        try bytes.write(to: definitiveURL)
        try bytes.write(to: redundantURL)
        let definitive = record(id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCC1", name: "original.txt", hash: "fixture-hash", url: definitiveURL)
        let redundant = record(id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCC2", name: "copy.txt", hash: "fixture-hash", url: redundantURL)
        let group = DuplicateGroup(identifier: "fixture-hash", documents: [definitive, redundant])
        let inventory = Inventory()
        inventory.replaceRecommendations(with: RecommendationService().generate(from: [group]).recommendations)

        #expect(inventory.selectDefinitiveCopy(id: "fixture-hash", documentID: definitive.id, groupDocumentIDs: [definitive.id, redundant.id]))
        #expect(inventory.updateRecommendationDecision(id: "fixture-hash", decision: .approved))
        let plan = ExecutionPlanService().generate(recommendations: inventory.recommendations, documents: group.documents, scanSessionID: sessionID)
        _ = await ExecutionPlanValidator().validate(
            plan,
            recommendations: inventory.recommendations,
            documents: group.documents,
            currentScanSessionID: sessionID
        )

        #expect(try Data(contentsOf: definitiveURL) == bytes)
        #expect(try Data(contentsOf: redundantURL) == bytes)
    }

    @MainActor
    @Test func resettingApprovedGroupPreservesOtherGroupAndPlan() async throws {
        let firstGroup = duplicateGroup(hash: "reset-first")
        let secondGroup = duplicateGroup(hash: "reset-second", idOffset: 10)
        let manager = configuredManager(groups: [firstGroup, secondGroup])

        await manager.approveArchival(id: firstGroup.identifier, definitiveDocumentID: firstGroup.documents[0].id)
        await manager.approveArchival(id: secondGroup.identifier, definitiveDocumentID: secondGroup.documents[0].id)
        let preserved = manager.recommendations.first { $0.id == secondGroup.identifier }!

        try await manager.resetDecision(id: firstGroup.identifier)

        let expected = RecommendationService().generate(from: [firstGroup]).recommendations[0]
        #expect(manager.recommendations.first { $0.id == firstGroup.identifier } == expected)
        #expect(manager.recommendations.first { $0.id == secondGroup.identifier } == preserved)
        #expect(manager.executionPlan?.operations.allSatisfy { $0.recommendationID == secondGroup.identifier } == true)
        #expect(manager.executionPlan?.operations.count == secondGroup.documents.count - 1)
        #expect(manager.currentSession?.acceptedRecommendationCount == 1)
    }

    @MainActor
    @Test func resettingRejectedAndPostponedGroupsIsIsolated() async throws {
        let firstGroup = duplicateGroup(hash: "reset-rejected")
        let secondGroup = duplicateGroup(hash: "reset-postponed", idOffset: 10)
        let manager = configuredManager(groups: [firstGroup, secondGroup])
        let firstBaseline = manager.recommendations.first { $0.id == firstGroup.identifier }!
        let secondBaseline = manager.recommendations.first { $0.id == secondGroup.identifier }!

        await manager.rejectRecommendation(id: firstGroup.identifier)
        await manager.postponeRecommendation(id: secondGroup.identifier)
        let postponed = manager.recommendations.first { $0.id == secondGroup.identifier }!
        try await manager.resetDecision(id: firstGroup.identifier)
        #expect(manager.recommendations.first { $0.id == firstGroup.identifier } == firstBaseline)
        #expect(manager.recommendations.first { $0.id == secondGroup.identifier } == postponed)
        #expect(manager.currentSession?.rejectedRecommendationCount == 0)

        try await manager.resetDecision(id: secondGroup.identifier)
        #expect(manager.recommendations.first { $0.id == secondGroup.identifier } == secondBaseline)
    }

    @MainActor
    @Test func resetRestoresEvidenceBackedBaselineAfterManualOverride() async throws {
        let group = duplicateGroup(hash: "reset-evidence", evidencedIndex: 0)
        let manager = configuredManager(groups: [group])
        let baseline = manager.recommendations[0]

        await manager.approveArchival(id: group.identifier, definitiveDocumentID: group.documents[1].id)
        try await manager.resetDecision(id: group.identifier)

        #expect(manager.recommendations[0] == baseline)
        #expect(manager.recommendations[0].definitiveDocumentID == group.documents[0].id)
        #expect(manager.recommendations[0].redundantDocumentIDs == [group.documents[1].id])
        #expect(manager.recommendations[0].status == .readyForApproval)
        #expect(manager.recommendations[0].isDeterministic)
        #expect(!manager.recommendations[0].isManuallySelected)
        #expect(manager.recommendations[0].decision == .pending)
    }

    @MainActor
    @Test func globalResetRestoresEveryGeneratedBaseline() async throws {
        let manualGroup = duplicateGroup(hash: "reset-all-manual")
        let evidenceGroup = duplicateGroup(hash: "reset-all-evidence", evidencedIndex: 0, idOffset: 10)
        let groups = [manualGroup, evidenceGroup]
        let manager = configuredManager(groups: groups)
        let baselines = manager.recommendations

        await manager.selectDefinitiveCopy(id: manualGroup.identifier, documentID: manualGroup.documents[0].id)
        await manager.rejectRecommendation(id: manualGroup.identifier)
        await manager.selectDefinitiveCopy(id: evidenceGroup.identifier, documentID: evidenceGroup.documents[1].id)
        await manager.postponeRecommendation(id: evidenceGroup.identifier)
        try await manager.resetAllDecisions()

        #expect(manager.recommendations == baselines)
        #expect(manager.currentSession?.acceptedRecommendationCount == 0)
        #expect(manager.currentSession?.rejectedRecommendationCount == 0)
    }

    @MainActor
    @Test func resetRejectsMissingGroupWithoutChangingRecommendationOrPlan() async {
        let group = duplicateGroup(hash: "reset-failure")
        let manager = configuredManager(groups: [group])
        await manager.approveArchival(id: group.identifier, definitiveDocumentID: group.documents[0].id)
        let recommendation = manager.recommendations[0]
        let plan = manager.executionPlan
        manager.inventory.replace(with: [group.documents[0]])

        do {
            try await manager.resetDecision(id: group.identifier)
            Issue.record("Expected reset to fail")
        } catch {
            #expect(error is RecommendationResetError)
        }

        #expect(manager.recommendations[0] == recommendation)
        #expect(manager.executionPlan == plan)
    }

    @MainActor
    @Test func stalePlanCannotSurviveResetAndResetDoesNotModifyFiles() async throws {
        let testDirectory = FileManager.default.temporaryDirectory
            .appending(path: "DocumentConsolidate-Reset-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDirectory) }
        let bytes = Data("unchanged reset fixture".utf8)
        let firstURL = testDirectory.appending(path: "first.txt")
        let secondURL = testDirectory.appending(path: "second.txt")
        try bytes.write(to: firstURL)
        try bytes.write(to: secondURL)
        let group = DuplicateGroup(identifier: "reset-stale", documents: [
            record(id: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEE1", name: "first.txt", hash: "reset-stale", url: firstURL),
            record(id: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEE2", name: "second.txt", hash: "reset-stale", url: secondURL)
        ])
        let manager = configuredManager(groups: [group])
        await manager.approveArchival(id: group.identifier, definitiveDocumentID: group.documents[0].id)
        let stalePlan = manager.executionPlan!
        let staleGeneration = manager.inventory.beginExecutionPlanGeneration()

        try await manager.resetDecision(id: group.identifier)
        manager.inventory.finishExecutionPlanGeneration(
            with: stalePlan,
            generation: staleGeneration.generation,
            decisionRevision: staleGeneration.decisionRevision
        )

        #expect(manager.executionPlan?.operations.isEmpty == true)
        #expect(try Data(contentsOf: firstURL) == bytes)
        #expect(try Data(contentsOf: secondURL) == bytes)
    }

    private func duplicateGroup(
        hash: String,
        count: Int = 2,
        evidencedIndex: Int? = nil,
        idOffset: Int = 0
    ) -> DuplicateGroup {
        let documents = (0..<count).map { index in
            record(
                id: String(format: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDD%02d", index + idOffset),
                name: "duplicate-\(index).txt",
                hash: hash,
                hasEvidence: evidencedIndex == index
            )
        }
        return DuplicateGroup(identifier: hash, documents: documents)
    }

    @MainActor
    private func configuredManager(groups: [DuplicateGroup]) -> ScanManager {
        let inventory = Inventory()
        let manager = ScanManager(inventory: inventory)
        _ = manager.createSession()
        inventory.replace(with: groups.flatMap(\.documents))
        inventory.replaceRecommendations(with: RecommendationService().generate(from: groups).recommendations)
        manager.refreshRecommendationSummary()
        return manager
    }

    private func record(
        id: String,
        name: String,
        hash: String,
        url: URL? = nil,
        hasEvidence: Bool = false
    ) -> DocumentRecord {
        DocumentRecord(
            id: UUID(uuidString: id)!,
            scanSessionID: sessionID,
            url: url ?? URL(filePath: "/fixtures/\(name)"),
            filename: name,
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
            hasApprovedDefinitiveCopyEvidence: hasEvidence
        )
    }
}
