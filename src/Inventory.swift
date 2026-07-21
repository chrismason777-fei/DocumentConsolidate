// 2026-07-21 16:46 SGT

import Foundation
import Observation

@MainActor
@Observable
final class Inventory {
    private(set) var scanSessionID: UUID?
    private(set) var documents: [DocumentRecord] = []
    private(set) var recommendations: [DuplicateRecommendation] = []
    private(set) var archivePlanningState: ArchivePlanningState?
    private(set) var executionPlanDecisionRevision = 0
    private(set) var activeExecutionPlanGeneration: Int?
    private var executionPlanGenerationSequence = 0

    var isGeneratingExecutionPlan: Bool { activeExecutionPlanGeneration != nil }
    var executionPlan: ExecutionPlan? { archivePlanningState?.plan }
    var archiveDestination: ArchiveDestination? { archivePlanningState?.destination }

    @discardableResult
    func add(_ document: DocumentRecord) -> Bool {
        let canonicalURL = document.url.standardizedFileURL.resolvingSymlinksInPath()
        guard !documents.contains(where: {
            $0.id == document.id
                || $0.url.standardizedFileURL.resolvingSymlinksInPath() == canonicalURL
        }) else {
            return false
        }

        documents.append(document)
        return true
    }

    func remove(id: UUID) {
        documents.removeAll { $0.id == id }
    }

    func clear() {
        documents.removeAll()
    }

    func replace(with documents: [DocumentRecord]) {
        self.documents = documents
    }

    func update(_ document: DocumentRecord) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
    }

    func replaceRecommendations(with recommendations: [DuplicateRecommendation]) {
        self.recommendations = recommendations
        archivePlanningState = nil
        executionPlanDecisionRevision += 1
    }

    @discardableResult
    func resetRecommendation(id: String, to baseline: DuplicateRecommendation) -> Bool {
        guard let index = recommendations.firstIndex(where: { $0.id == id }),
              baseline.id == id,
              recommendations[index].duplicateGroupIdentifier == baseline.duplicateGroupIdentifier,
              recommendations[index].isDeterministic == baseline.isDeterministic else { return false }
        restoreRecommendation(at: index, from: baseline)
        invalidateExecutionPlan()
        return true
    }

    @discardableResult
    func resetRecommendationReview(to baselines: [DuplicateRecommendation]) -> Bool {
        guard baselines.count == recommendations.count else { return false }
        let baselinesByID = Dictionary(uniqueKeysWithValues: baselines.map { ($0.id, $0) })
        guard baselinesByID.count == recommendations.count,
              recommendations.allSatisfy({ recommendation in
                  guard let baseline = baselinesByID[recommendation.id] else { return false }
                  return recommendation.duplicateGroupIdentifier == baseline.duplicateGroupIdentifier
                      && recommendation.isDeterministic == baseline.isDeterministic
              }) else { return false }
        for index in recommendations.indices {
            restoreRecommendation(at: index, from: baselinesByID[recommendations[index].id]!)
        }
        invalidateExecutionPlan()
        return true
    }

    @discardableResult
    func updateRecommendationDecision(id: String, decision: RecommendationDecision) -> Bool {
        guard let index = recommendations.firstIndex(where: { $0.id == id }),
              decision != .approved || recommendations[index].isReadyForApproval,
              recommendations[index].decision != decision else { return false }
        recommendations[index].decision = decision
        executionPlanDecisionRevision += 1
        return true
    }

    @discardableResult
    func approveRecommendation(id: String, documentID: UUID, groupDocumentIDs: [UUID]) -> Bool {
        guard let index = recommendations.firstIndex(where: { $0.id == id }),
              groupDocumentIDs.contains(documentID) else { return false }
        let redundantIDs = groupDocumentIDs
            .filter { $0 != documentID }
            .sorted { $0.uuidString < $1.uuidString }
        guard !redundantIDs.isEmpty else { return false }

        let selectionChanged = recommendations[index].definitiveDocumentID != documentID
        recommendations[index].definitiveDocumentID = documentID
        recommendations[index].redundantDocumentIDs = redundantIDs
        recommendations[index].status = .readyForApproval
        if selectionChanged {
            recommendations[index].rationale = "Every file has the same content hash. The definitive copy was selected manually; every other byte-identical group member is a redundant archive candidate."
            recommendations[index].isManuallySelected = true
        }
        recommendations[index].decision = .approved
        executionPlanDecisionRevision += 1
        return true
    }

    @discardableResult
    func selectDefinitiveCopy(id: String, documentID: UUID, groupDocumentIDs: [UUID]) -> Bool {
        guard let index = recommendations.firstIndex(where: { $0.id == id }),
              groupDocumentIDs.contains(documentID) else { return false }
        let redundantIDs = groupDocumentIDs
            .filter { $0 != documentID }
            .sorted { $0.uuidString < $1.uuidString }
        guard !redundantIDs.isEmpty else { return false }

        recommendations[index].definitiveDocumentID = documentID
        recommendations[index].redundantDocumentIDs = redundantIDs
        recommendations[index].status = .readyForApproval
        recommendations[index].rationale = "Every file has the same content hash. The definitive copy was selected manually; every other byte-identical group member is a redundant archive candidate."
        recommendations[index].isManuallySelected = true
        recommendations[index].decision = .pending
        executionPlanDecisionRevision += 1
        return true
    }

    func replaceExecutionPlan(with executionPlan: ExecutionPlan?) {
        guard let executionPlan else {
            archivePlanningState = nil
            return
        }
        archivePlanningState = ArchivePlanningState(
            plan: executionPlan,
            destination: archivePlanningState?.destination
        )
    }

    func replaceArchivePlanningState(with state: ArchivePlanningState?) {
        archivePlanningState = state
    }

    func beginExecutionPlanGeneration() -> (generation: Int, decisionRevision: Int) {
        executionPlanGenerationSequence += 1
        activeExecutionPlanGeneration = executionPlanGenerationSequence
        return (executionPlanGenerationSequence, executionPlanDecisionRevision)
    }

    func finishExecutionPlanGeneration(
        with executionPlan: ExecutionPlan,
        generation: Int,
        decisionRevision: Int
    ) {
        guard activeExecutionPlanGeneration == generation,
              executionPlanDecisionRevision == decisionRevision else { return }
        archivePlanningState = ArchivePlanningState(
            plan: executionPlan,
            destination: archivePlanningState?.destination
        )
        activeExecutionPlanGeneration = nil
    }

    func reset(for scanSessionID: UUID?) {
        self.scanSessionID = scanSessionID
        clear()
        recommendations.removeAll()
        archivePlanningState = nil
        executionPlanDecisionRevision += 1
        activeExecutionPlanGeneration = nil
    }

    private func restoreRecommendation(at index: Int, from baseline: DuplicateRecommendation) {
        recommendations[index].definitiveDocumentID = baseline.definitiveDocumentID
        recommendations[index].redundantDocumentIDs = baseline.redundantDocumentIDs
        recommendations[index].status = baseline.status
        recommendations[index].rationale = baseline.rationale
        recommendations[index].isManuallySelected = baseline.isManuallySelected
        recommendations[index].decision = .pending
    }

    private func invalidateExecutionPlan() {
        archivePlanningState = nil
        executionPlanDecisionRevision += 1
        activeExecutionPlanGeneration = nil
    }
}
