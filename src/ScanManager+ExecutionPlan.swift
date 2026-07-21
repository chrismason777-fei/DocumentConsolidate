// 2026-07-21 17:27 SGT

import Foundation

extension ScanManager {
    func generateExecutionPlan() async {
        guard let session = currentSession else { return }
        let generation = inventory.beginExecutionPlanGeneration()
        let plan = ExecutionPlanService().generate(
            recommendations: recommendations,
            documents: documents,
            scanRoots: selectedRootFolders,
            archiveDestination: inventory.archiveDestination,
            scanSessionID: session.id,
            decisionRevision: generation.decisionRevision,
            createdAt: Date()
        )
        inventory.replaceExecutionPlan(with: plan)
        let validatedPlan = await ExecutionPlanValidator().validate(
            plan,
            recommendations: recommendations,
            documents: documents,
            currentScanSessionID: currentSession?.id
        )
        inventory.finishExecutionPlanGeneration(
            with: validatedPlan,
            generation: generation.generation,
            decisionRevision: generation.decisionRevision
        )
    }
}
