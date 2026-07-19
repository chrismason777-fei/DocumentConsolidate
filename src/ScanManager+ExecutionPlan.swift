// 2026-07-19 13:45 SGT

extension ScanManager {
    func generateExecutionPlan() async {
        guard let session = currentSession else { return }
        let generation = inventory.beginExecutionPlanGeneration()
        let plan = ExecutionPlanService().generate(
            recommendations: recommendations,
            documents: documents,
            scanSessionID: session.id
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
