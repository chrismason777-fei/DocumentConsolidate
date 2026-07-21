// 2026-07-21 17:49 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

@MainActor
struct ArchivePlanningLifecycleTests {
    private let sessionID = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!

    @Test func acceptedStateRemainsVisibleDuringRegeneration() {
        let inventory = Inventory()
        let accepted = state(id: "accepted")
        inventory.replaceArchivePlanningState(with: accepted)

        _ = inventory.beginExecutionPlanGeneration()

        #expect(inventory.archivePlanningState == accepted)
        #expect(inventory.isGeneratingExecutionPlan)
    }

    @Test func successfulCandidateAtomicallyReplacesAcceptedState() {
        let inventory = Inventory()
        let accepted = state(id: "accepted")
        inventory.replaceArchivePlanningState(with: accepted)
        let generation = inventory.beginExecutionPlanGeneration()
        let candidate = state(id: "replacement", decisionRevision: generation.decisionRevision)

        let result = inventory.acceptArchivePlanningState(
            candidate,
            generation: generation.generation,
            decisionRevision: generation.decisionRevision
        )

        #expect(result == .accepted)
        #expect(inventory.archivePlanningState == candidate)
        #expect(!inventory.isGeneratingExecutionPlan)
    }

    @Test func failedPlanningPreservesAcceptedState() async {
        let inventory = Inventory()
        let accepted = state(id: "accepted")
        inventory.replaceArchivePlanningState(with: accepted)
        let manager = ScanManager(inventory: inventory)

        let result = await manager.generateExecutionPlan()

        #expect(result == .failure(.noScanSession))
        #expect(inventory.archivePlanningState == accepted)
    }

    @Test func staleGenerationCannotReplaceAcceptedState() {
        let inventory = Inventory()
        let accepted = state(id: "accepted")
        inventory.replaceArchivePlanningState(with: accepted)
        let stale = inventory.beginExecutionPlanGeneration()
        _ = inventory.beginExecutionPlanGeneration()
        let candidate = state(id: "stale", decisionRevision: stale.decisionRevision)

        let result = inventory.acceptArchivePlanningState(
            candidate,
            generation: stale.generation,
            decisionRevision: stale.decisionRevision
        )

        #expect(result == .staleGeneration)
        #expect(inventory.archivePlanningState == accepted)
        #expect(inventory.isGeneratingExecutionPlan)
    }

    @Test func cancellationPreservesAcceptedState() async {
        let inventory = Inventory()
        inventory.reset(for: sessionID)
        let accepted = state(id: "accepted", decisionRevision: inventory.executionPlanDecisionRevision)
        inventory.replaceArchivePlanningState(with: accepted)
        let manager = ScanManager(inventory: inventory)
        manager.currentSession = ScanSession(id: sessionID, sourceFolders: [])

        let result = await Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await manager.generateExecutionPlan()
        }.value

        #expect(result == .failure(.cancelled))
        #expect(inventory.archivePlanningState == accepted)
        #expect(!inventory.isGeneratingExecutionPlan)
    }

    @Test func validationFailurePreservesAcceptedState() {
        let inventory = Inventory()
        let accepted = state(id: "accepted")
        inventory.replaceArchivePlanningState(with: accepted)
        let generation = inventory.beginExecutionPlanGeneration()
        let candidate = state(
            id: "invalid",
            decisionRevision: generation.decisionRevision,
            operations: [invalidOperation()]
        )

        let result = inventory.acceptArchivePlanningState(
            candidate,
            generation: generation.generation,
            decisionRevision: generation.decisionRevision
        )

        #expect(result == .validationFailed)
        #expect(inventory.archivePlanningState == accepted)
        #expect(!inventory.isGeneratingExecutionPlan)
    }

    @Test func generationPublishesAtMostOneAcceptedState() {
        let inventory = Inventory()
        inventory.replaceArchivePlanningState(with: state(id: "accepted"))
        let generation = inventory.beginExecutionPlanGeneration()
        let first = state(id: "first", decisionRevision: generation.decisionRevision)
        let second = state(id: "second", decisionRevision: generation.decisionRevision)

        let firstResult = inventory.acceptArchivePlanningState(
            first,
            generation: generation.generation,
            decisionRevision: generation.decisionRevision
        )
        let secondResult = inventory.acceptArchivePlanningState(
            second,
            generation: generation.generation,
            decisionRevision: generation.decisionRevision
        )

        #expect(firstResult == .accepted)
        #expect(secondResult == .staleGeneration)
        #expect(inventory.archivePlanningState == first)
    }

    private func state(
        id: String,
        decisionRevision: Int = 0,
        operations: [PlannedOperation] = []
    ) -> ArchivePlanningState {
        ArchivePlanningState(
            plan: ExecutionPlan(
                id: id,
                scanSessionID: sessionID,
                operations: operations,
                decisionRevision: decisionRevision
            ),
            destination: nil
        )
    }

    private func invalidOperation() -> PlannedOperation {
        let definitive = DocumentRecord(
            scanSessionID: sessionID,
            url: URL(filePath: "/definitive.txt"),
            filename: "definitive.txt",
            fileExtension: "txt",
            fileSize: 1,
            createdAt: nil,
            modifiedAt: nil,
            contentHash: "hash"
        )
        return PlannedOperation(
            id: "invalid-operation",
            type: .archiveRedundantCopy,
            sourceDocument: nil,
            destination: nil,
            definitiveDocument: definitive,
            reason: "Test",
            recommendationID: "hash",
            expectedHash: nil,
            expectedDefinitiveHash: "hash",
            executionStatus: .notStarted,
            validationStatus: .invalid,
            validationIssues: ["Invalid test candidate."]
        )
    }
}
