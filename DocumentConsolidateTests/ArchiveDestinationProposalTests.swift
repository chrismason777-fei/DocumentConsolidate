// 2026-07-21 18:04 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

@MainActor
struct ArchiveDestinationProposalTests {
    private let sessionID = UUID(uuidString: "12121212-3434-5656-7878-909090909090")!

    @Test func proposedDestinationGeneratesAgainstCandidateOnly() async throws {
        let manager = configuredManager()
        let accepted = destination("Accepted")
        manager.inventory.replaceArchivePlanningState(
            with: state(id: "accepted", destination: accepted, revision: manager.inventory.executionPlanDecisionRevision)
        )
        let proposed = destination("Proposed")

        let result = await manager.generateExecutionPlan(for: proposed, destinationAccess: PassthroughAccess())
        let candidate = try #require(result.success)

        #expect(candidate.destination == proposed)
        #expect(candidate.plan.destinationRoot == proposed.canonicalRootURL)
        #expect(candidate.plan.destinationRoot != accepted.canonicalRootURL)
    }

    @Test func successfulProposalAtomicallyReplacesDestinationAndPlan() async throws {
        let manager = configuredManager()
        let accepted = state(
            id: "accepted",
            destination: destination("Accepted"),
            revision: manager.inventory.executionPlanDecisionRevision
        )
        manager.inventory.replaceArchivePlanningState(with: accepted)
        let proposed = destination("Replacement")

        let result = await manager.generateExecutionPlan(for: proposed, destinationAccess: PassthroughAccess())
        let replacement = try #require(result.success)

        #expect(manager.inventory.archivePlanningState == replacement)
        #expect(manager.inventory.archivePlanningState != accepted)
        #expect(manager.inventory.archiveDestination == proposed)
    }

    @Test func failedProposalPreservesAcceptedDestinationAndPlan() async {
        let manager = configuredManagerWithInvalidOperation()
        let accepted = state(
            id: "accepted",
            destination: destination("Accepted"),
            revision: manager.inventory.executionPlanDecisionRevision
        )
        manager.inventory.replaceArchivePlanningState(with: accepted)

        let result = await manager.generateExecutionPlan(
            for: destination("Rejected"),
            destinationAccess: PassthroughAccess()
        )

        #expect(result == .failure(.validationFailed))
        #expect(manager.inventory.archivePlanningState == accepted)
    }

    @Test func staleProposalCannotReplaceAcceptedState() {
        let inventory = Inventory()
        let accepted = state(id: "accepted", destination: destination("Accepted"))
        inventory.replaceArchivePlanningState(with: accepted)
        let stale = inventory.beginExecutionPlanGeneration()
        _ = inventory.beginExecutionPlanGeneration()
        let proposed = state(
            id: "stale",
            destination: destination("Proposed"),
            revision: stale.decisionRevision
        )

        let result = inventory.acceptArchivePlanningState(
            proposed,
            generation: stale.generation,
            decisionRevision: stale.decisionRevision
        )

        #expect(result == .staleGeneration)
        #expect(inventory.archivePlanningState == accepted)
    }

    @Test func refreshUsesCurrentlyAcceptedDestination() async throws {
        let manager = configuredManager()
        let acceptedDestination = destination("Accepted")
        manager.inventory.replaceArchivePlanningState(
            with: state(
                id: "accepted",
                destination: acceptedDestination,
                revision: manager.inventory.executionPlanDecisionRevision
            )
        )

        let result = await manager.generateExecutionPlan(destinationAccess: PassthroughAccess())
        let refreshed = try #require(result.success)

        #expect(refreshed.destination == acceptedDestination)
        #expect(refreshed.plan.destinationRoot == acceptedDestination.canonicalRootURL)
    }

    @Test func clearIsIndependentFromRefresh() async throws {
        let manager = configuredManager()
        let acceptedDestination = destination("Accepted")
        manager.inventory.replaceArchivePlanningState(
            with: state(
                id: "accepted",
                destination: acceptedDestination,
                revision: manager.inventory.executionPlanDecisionRevision
            )
        )

        let result = await manager.clearArchiveDestination()
        let cleared = try #require(result.success)

        #expect(cleared.destination == nil)
        #expect(cleared.plan.destinationRoot == nil)
        #expect(manager.inventory.archiveDestination == nil)
    }

    private func configuredManager() -> ScanManager {
        let inventory = Inventory()
        inventory.reset(for: sessionID)
        let manager = ScanManager(inventory: inventory)
        manager.currentSession = ScanSession(id: sessionID, sourceFolders: [])
        return manager
    }

    private func configuredManagerWithInvalidOperation() -> ScanManager {
        let manager = configuredManager()
        let definitive = document(id: 1, name: "definitive.txt")
        let redundant = document(id: 2, name: "redundant.txt")
        manager.inventory.replace(with: [definitive, redundant])
        manager.inventory.replaceRecommendations(with: [
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
        ])
        return manager
    }

    private func state(
        id: String,
        destination: ArchiveDestination?,
        revision: Int = 0
    ) -> ArchivePlanningState {
        ArchivePlanningState(
            plan: ExecutionPlan(
                id: id,
                scanSessionID: sessionID,
                operations: [],
                destinationRoot: destination?.canonicalRootURL,
                decisionRevision: revision
            ),
            destination: destination
        )
    }

    private func destination(_ name: String) -> ArchiveDestination {
        ArchiveDestination(
            canonicalRootURL: URL(filePath: "/Archive/\(name)"),
            securityScopedBookmarkData: Data(name.utf8)
        )
    }

    private func document(id: Int, name: String) -> DocumentRecord {
        DocumentRecord(
            id: UUID(uuidString: String(format: "BBBBBBBB-BBBB-BBBB-BBBB-%012d", id))!,
            scanSessionID: sessionID,
            url: URL(filePath: "/fixtures/\(name)"),
            filename: name,
            fileExtension: "txt",
            fileSize: 1,
            createdAt: nil,
            modifiedAt: nil,
            contentHash: "hash"
        )
    }
}

private extension Result {
    var success: Success? {
        guard case let .success(value) = self else { return nil }
        return value
    }
}

private struct PassthroughAccess: ArchiveDestinationAccessProviding {
    func authorize(selectedURL: URL, scanRoots: [URL]) throws -> ArchiveDestination {
        ArchiveDestination(canonicalRootURL: selectedURL, securityScopedBookmarkData: nil)
    }

    func withAccess<T>(to destination: ArchiveDestination, operation: (URL) throws -> T) throws -> T {
        try operation(destination.canonicalRootURL)
    }
}
