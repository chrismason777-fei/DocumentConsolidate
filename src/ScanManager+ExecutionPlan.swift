// 2026-07-21 17:46 SGT

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
        guard let session = currentSession else { return .failure(.noScanSession) }
        let generation = inventory.beginExecutionPlanGeneration()
        let destination = inventory.archiveDestination
        let plan = ExecutionPlanService().generate(
            recommendations: recommendations,
            documents: documents,
            scanRoots: selectedRootFolders,
            archiveDestination: destination,
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
        let candidate = ArchivePlanningState(plan: validatedPlan, destination: destination)
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
