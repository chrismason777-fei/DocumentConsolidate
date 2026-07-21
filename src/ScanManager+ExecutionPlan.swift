// 2026-07-21 18:03 SGT

import Foundation

enum ArchivePlanningLifecycleError: Error, Equatable, Sendable {
    case noScanSession
    case cancelled
    case validationFailed
    case staleGeneration
}

extension ScanManager {
    @discardableResult
    func generateExecutionPlan() async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        await generateExecutionPlan(for: inventory.archiveDestination)
    }

    @discardableResult
    func clearArchiveDestination() async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        await generateExecutionPlan(for: nil)
    }

    @discardableResult
    func generateExecutionPlan(
        for proposedDestination: ArchiveDestination?
    ) async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        guard let session = currentSession else { return .failure(.noScanSession) }
        let generation = inventory.beginExecutionPlanGeneration()
        let plan = ExecutionPlanService().generate(
            recommendations: recommendations,
            documents: documents,
            scanRoots: selectedRootFolders,
            archiveDestination: proposedDestination,
            scanSessionID: session.id,
            decisionRevision: generation.decisionRevision,
            createdAt: Date()
        )
        guard !Task.isCancelled else {
            inventory.cancelExecutionPlanGeneration(generation.generation)
            return .failure(.cancelled)
        }
        let validatedPlan = await ExecutionPlanValidator().validate(
            plan,
            recommendations: recommendations,
            documents: documents,
            currentScanSessionID: currentSession?.id
        )
        guard !Task.isCancelled else {
            inventory.cancelExecutionPlanGeneration(generation.generation)
            return .failure(.cancelled)
        }
        let candidate = ArchivePlanningState(plan: validatedPlan, destination: proposedDestination)
        switch inventory.acceptArchivePlanningState(
            candidate,
            generation: generation.generation,
            decisionRevision: generation.decisionRevision
        ) {
        case .accepted:
            return .success(candidate)
        case .validationFailed:
            return .failure(.validationFailed)
        case .staleGeneration:
            return .failure(.staleGeneration)
        }
    }
}
