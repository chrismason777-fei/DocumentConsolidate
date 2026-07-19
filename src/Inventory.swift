// 2026-07-19 17:25 SGT

import Foundation
import Observation

@MainActor
@Observable
final class Inventory {
    private(set) var scanSessionID: UUID?
    private(set) var documents: [DocumentRecord] = []
    private(set) var recommendations: [DuplicateRecommendation] = []
    private(set) var executionPlan: ExecutionPlan?
    private(set) var executionPlanDecisionRevision = 0
    private(set) var activeExecutionPlanGeneration: Int?
    private var executionPlanGenerationSequence = 0

    var isGeneratingExecutionPlan: Bool { activeExecutionPlanGeneration != nil }

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
        executionPlan = nil
        executionPlanDecisionRevision += 1
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
        self.executionPlan = executionPlan
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
        self.executionPlan = executionPlan
        activeExecutionPlanGeneration = nil
    }

    func reset(for scanSessionID: UUID?) {
        self.scanSessionID = scanSessionID
        clear()
        recommendations.removeAll()
        executionPlan = nil
        executionPlanDecisionRevision += 1
        activeExecutionPlanGeneration = nil
    }
}
