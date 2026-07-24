// 2026-07-24 15:49 SGT

import Foundation

enum ArchivePlanningLifecycleError: Error, Equatable, Sendable {
    case noScanSession
    case cancelled
    case destinationAccess(ArchiveDestinationAccessError)
    case destinationAccessFailed
    case validationFailed
    case staleGeneration
}

enum ExecutionLifecycleError: Error, Equatable, Sendable {
    case noPublishedPlan
    case executionInProgress
    case destinationAccess(ArchiveDestinationAccessError)
    case destinationAccessFailed
    case globalPreflightFailed(String)
}

extension ScanManager {
    @discardableResult
    func executePublishedPlan() async -> Result<ExecutionSummary, ExecutionLifecycleError> {
        guard !inventory.isExecuting else { return .failure(.executionInProgress) }
        guard let state = inventory.beginExecution(), let destination = state.destination else {
            return .failure(.noPublishedPlan)
        }
        defer { inventory.finishExecution() }

        do {
            let summary = try await ArchiveDestinationAccess().withAccess(to: destination) { authorizedRoot in
                try await ExecutionEngine().execute(state.plan, authorizedRoot: authorizedRoot)
            }
            return .success(summary)
        } catch let error as ArchiveDestinationAccessError {
            return .failure(.destinationAccess(error))
        } catch let error as ExecutionEngineError {
            switch error {
            case .invalidPlan(let message):
                return .failure(.globalPreflightFailed(message))
            }
        } catch {
            return .failure(.destinationAccessFailed)
        }
    }

    @discardableResult
    func generateExecutionPlan() async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        await generateExecutionPlan(for: inventory.archiveDestination)
    }

    @discardableResult
    func generateExecutionPlan<Access: ArchiveDestinationAccessProviding>(
        destinationAccess: Access
    ) async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        await generateExecutionPlan(
            for: inventory.archiveDestination,
            destinationAccess: destinationAccess
        )
    }

    @discardableResult
    func clearArchiveDestination() async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        await generateExecutionPlan(for: nil)
    }

    @discardableResult
    func generateExecutionPlan(
        for proposedDestination: ArchiveDestination?
    ) async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        await generateExecutionPlan(
            for: proposedDestination,
            destinationAccess: ArchiveDestinationAccess()
        )
    }

    @discardableResult
    func generateExecutionPlan<Access: ArchiveDestinationAccessProviding>(
        for proposedDestination: ArchiveDestination?,
        destinationAccess: Access
    ) async -> Result<ArchivePlanningState, ArchivePlanningLifecycleError> {
        guard let session = currentSession else { return .failure(.noScanSession) }
        let generation = inventory.beginExecutionPlanGeneration()
        let derivePlan = {
            ExecutionPlanService().generate(
                recommendations: self.recommendations,
                documents: self.documents,
                scanRoots: self.selectedRootFolders,
                archiveDestination: proposedDestination,
                scanSessionID: session.id,
                decisionRevision: generation.decisionRevision,
                createdAt: Date()
            )
        }
        let plan: ExecutionPlan
        do {
            if let proposedDestination {
                plan = try destinationAccess.withAccess(to: proposedDestination) { _ in derivePlan() }
            } else {
                plan = derivePlan()
            }
        } catch let error as ArchiveDestinationAccessError {
            inventory.cancelExecutionPlanGeneration(generation.generation)
            return .failure(.destinationAccess(error))
        } catch {
            inventory.cancelExecutionPlanGeneration(generation.generation)
            return .failure(.destinationAccessFailed)
        }
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
