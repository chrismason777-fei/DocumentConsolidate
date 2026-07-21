// 2026-07-21 16:46 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

struct ArchivePlanningStateOwnershipTests {
    private let sessionID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @MainActor
    @Test func inventoryInitiallyHasNoPlanningState() {
        let inventory = Inventory()
        #expect(inventory.archivePlanningState == nil)
        #expect(inventory.executionPlan == nil)
        #expect(inventory.archiveDestination == nil)
    }

    @MainActor
    @Test func planPublishesWithoutDestinationThroughCompatibilityAccessor() {
        let inventory = Inventory()
        let plan = makePlan(id: "initial")
        inventory.replaceExecutionPlan(with: plan)

        #expect(inventory.archivePlanningState == ArchivePlanningState(plan: plan, destination: nil))
        #expect(inventory.executionPlan == plan)
        #expect(inventory.archiveDestination == nil)
    }

    @MainActor
    @Test func replacingPlanPreservesAcceptedDestinationWithoutMutatingPriorValue() {
        let inventory = Inventory()
        let firstPlan = makePlan(id: "first")
        let secondPlan = makePlan(id: "second")
        let destination = ArchiveDestination(
            canonicalRootURL: URL(filePath: "/Archive"),
            securityScopedBookmarkData: Data("bookmark".utf8)
        )
        let priorState = ArchivePlanningState(plan: firstPlan, destination: destination)
        inventory.replaceArchivePlanningState(with: priorState)

        inventory.replaceExecutionPlan(with: secondPlan)

        #expect(inventory.archivePlanningState == ArchivePlanningState(plan: secondPlan, destination: destination))
        #expect(inventory.archiveDestination == destination)
        #expect(priorState.plan == firstPlan)
        #expect(priorState.destination == destination)
    }

    @MainActor
    @Test func clearingPlanClearsEntirePlanningState() {
        let inventory = Inventory()
        inventory.replaceArchivePlanningState(
            with: ArchivePlanningState(plan: makePlan(id: "existing"), destination: makeDestination())
        )

        inventory.replaceExecutionPlan(with: nil)

        #expect(inventory.archivePlanningState == nil)
        #expect(inventory.executionPlan == nil)
        #expect(inventory.archiveDestination == nil)
    }

    @MainActor
    @Test func newScanClearsPlanningStateWithoutReplacingInventory() {
        let inventory = Inventory()
        let manager = ScanManager(inventory: inventory)
        inventory.replaceArchivePlanningState(
            with: ArchivePlanningState(plan: makePlan(id: "existing"), destination: makeDestination())
        )

        _ = manager.createSession()

        #expect(manager.inventory === inventory)
        #expect(inventory.archivePlanningState == nil)
    }

    @MainActor
    @Test func existingGenerationPublishesPlanWithoutDestination() async {
        let inventory = Inventory()
        let manager = ScanManager(inventory: inventory)
        _ = manager.createSession()

        await manager.generateExecutionPlan()

        #expect(inventory.archivePlanningState != nil)
        #expect(inventory.executionPlan?.operations.isEmpty == true)
        #expect(inventory.archiveDestination == nil)
    }

    @MainActor
    @Test func validatedGenerationPreservesExistingDestination() {
        let inventory = Inventory()
        inventory.reset(for: sessionID)
        let destination = makeDestination()
        inventory.replaceArchivePlanningState(
            with: ArchivePlanningState(plan: makePlan(id: "prior"), destination: destination)
        )
        let generation = inventory.beginExecutionPlanGeneration()
        let replacement = makePlan(id: "validated")

        inventory.finishExecutionPlanGeneration(
            with: replacement,
            generation: generation.generation,
            decisionRevision: generation.decisionRevision
        )

        #expect(inventory.executionPlan == replacement)
        #expect(inventory.archiveDestination == destination)
    }

    private func makePlan(id: String) -> ExecutionPlan {
        ExecutionPlan(id: id, scanSessionID: sessionID, operations: [])
    }

    private func makeDestination() -> ArchiveDestination {
        ArchiveDestination(
            canonicalRootURL: URL(filePath: "/Archive"),
            securityScopedBookmarkData: Data("bookmark".utf8)
        )
    }
}
