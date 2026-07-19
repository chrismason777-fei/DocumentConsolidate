// 2026-07-19 17:25 SGT
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

    private func duplicateGroup(hash: String, count: Int = 2, evidencedIndex: Int? = nil) -> DuplicateGroup {
        let documents = (0..<count).map { index in
            record(
                id: String(format: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDD%02d", index),
                name: "duplicate-\(index).txt",
                hash: hash,
                hasEvidence: evidencedIndex == index
            )
        }
        return DuplicateGroup(identifier: hash, documents: documents)
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
