// 2026-07-21 18:17 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

@MainActor
struct ArchiveDestinationScopedPlanningTests {
    private let sessionID = UUID(uuidString: "23232323-4545-6767-8989-010101010101")!

    @Test func proposalDerivesWithinBalancedScopedAccessAndPublishesAtomically() async throws {
        let manager = configuredManager()
        let accepted = state(id: "accepted", destination: destination("Accepted"))
        manager.inventory.replaceArchivePlanningState(with: accepted)
        let access = TrackingAccess()
        let proposed = destination("Proposed")

        let result = await manager.generateExecutionPlan(for: proposed, destinationAccess: access)
        let replacement = try #require(result.success)

        #expect(access.operationObservedActive)
        #expect(access.startCount == 1)
        #expect(access.stopCount == 1)
        #expect(!access.isActive)
        #expect(replacement.destination == proposed)
        #expect(manager.inventory.archivePlanningState == replacement)
    }

    @Test func refreshReacquiresAcceptedDestinationAccess() async throws {
        let manager = configuredManager()
        let acceptedDestination = destination("Accepted")
        manager.inventory.replaceArchivePlanningState(
            with: state(id: "accepted", destination: acceptedDestination)
        )
        let access = TrackingAccess()

        let result = await manager.generateExecutionPlan(destinationAccess: access)

        #expect(try #require(result.success).destination == acceptedDestination)
        #expect(access.startCount == 1)
        #expect(access.stopCount == 1)
    }

    @Test func destinationFreePlanningAndClearDoNotRequestAccess() async throws {
        let manager = configuredManager()
        let access = TrackingAccess()

        let destinationFreeResult = await manager.generateExecutionPlan(for: nil, destinationAccess: access)
        _ = try #require(destinationFreeResult.success)
        #expect(access.startCount == 0)
        #expect(access.stopCount == 0)

        manager.inventory.replaceArchivePlanningState(
            with: state(id: "accepted", destination: destination("Accepted"))
        )
        let clearResult = await manager.clearArchiveDestination()
        _ = try #require(clearResult.success)
        #expect(access.startCount == 0)
        #expect(access.stopCount == 0)
    }

    @Test(arguments: [
        ArchiveDestinationAccessError.bookmarkResolutionFailed,
        .staleBookmark,
        .scopedAccessAcquisitionFailed
    ])
    func accessFailurePreservesAcceptedState(error: ArchiveDestinationAccessError) async {
        let manager = configuredManager()
        let accepted = state(id: "accepted", destination: destination("Accepted"))
        manager.inventory.replaceArchivePlanningState(with: accepted)
        let access = TrackingAccess(failure: error)

        let result = await manager.generateExecutionPlan(
            for: destination("Proposed"),
            destinationAccess: access
        )

        #expect(result == .failure(.destinationAccess(error)))
        #expect(manager.inventory.archivePlanningState == accepted)
        #expect(!manager.inventory.isGeneratingExecutionPlan)
        #expect(access.startCount == 0)
        #expect(access.stopCount == 0)
    }

    @Test func accessIsBalancedWhenValidationRejectsCandidate() async {
        let manager = configuredManagerWithInvalidOperation()
        let accepted = state(id: "accepted", destination: destination("Accepted"))
        manager.inventory.replaceArchivePlanningState(with: accepted)
        let access = TrackingAccess()

        let result = await manager.generateExecutionPlan(
            for: destination("Proposed"),
            destinationAccess: access
        )

        #expect(result == .failure(.validationFailed))
        #expect(manager.inventory.archivePlanningState == accepted)
        #expect(access.startCount == 1)
        #expect(access.stopCount == 1)
        #expect(!access.isActive)
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

    private func state(id: String, destination: ArchiveDestination?) -> ArchivePlanningState {
        ArchivePlanningState(
            plan: ExecutionPlan(
                id: id,
                scanSessionID: sessionID,
                operations: [],
                destinationRoot: destination?.canonicalRootURL,
                decisionRevision: 1
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
            id: UUID(uuidString: String(format: "CCCCCCCC-CCCC-CCCC-CCCC-%012d", id))!,
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

private final class TrackingAccess: ArchiveDestinationAccessProviding, @unchecked Sendable {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var isActive = false
    private(set) var operationObservedActive = false
    private let failure: ArchiveDestinationAccessError?

    init(failure: ArchiveDestinationAccessError? = nil) {
        self.failure = failure
    }

    func authorize(selectedURL: URL, scanRoots: [URL]) throws -> ArchiveDestination {
        ArchiveDestination(canonicalRootURL: selectedURL, securityScopedBookmarkData: nil)
    }

    func withAccess<T>(to destination: ArchiveDestination, operation: (URL) throws -> T) throws -> T {
        if let failure { throw failure }
        startCount += 1
        isActive = true
        defer {
            isActive = false
            stopCount += 1
        }
        operationObservedActive = isActive
        return try operation(destination.canonicalRootURL)
    }
}

private extension Result {
    var success: Success? {
        guard case let .success(value) = self else { return nil }
        return value
    }
}
