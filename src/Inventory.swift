// 2026-07-19 13:45 SGT

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
    }

    @discardableResult
    func updateRecommendationDecision(id: String, decision: RecommendationDecision) -> Bool {
        guard let index = recommendations.firstIndex(where: { $0.id == id }),
              recommendations[index].decision != decision else { return false }
        recommendations[index].decision = decision
        executionPlanDecisionRevision += 1
        return true
    }

    @discardableResult
    func updateRecommendationFileRole(
        id: String,
        documentID: UUID,
        role: RecommendationFileRole
    ) -> Bool {
        guard let index = recommendations.firstIndex(where: { $0.id == id }) else { return false }
        var recommendation = recommendations[index]

        switch role {
        case .retain:
            recommendation.selectedRetainedDocumentID = documentID
            recommendation.excludedDocumentIDs.removeAll { $0 == documentID }
        case .consolidate:
            if recommendation.selectedRetainedDocumentID == documentID {
                recommendation.selectedRetainedDocumentID = nil
            }
            recommendation.excludedDocumentIDs.removeAll { $0 == documentID }
        case .exclude:
            if recommendation.selectedRetainedDocumentID == documentID {
                recommendation.selectedRetainedDocumentID = nil
            }
            if !recommendation.excludedDocumentIDs.contains(documentID) {
                recommendation.excludedDocumentIDs.append(documentID)
            }
        }

        recommendation.proposedRetainedDocumentID = nil
        recommendation.proposedRedundantDocumentIDs = []
        recommendation.status = .requiresReview
        recommendation.decision = .pending
        recommendations[index] = recommendation
        executionPlanDecisionRevision += 1
        return true
    }

    @discardableResult
    func generateRecommendation(id: String, documentIDs: [UUID]) -> Bool {
        guard let index = recommendations.firstIndex(where: { $0.id == id }),
              let retainedID = recommendations[index].selectedRetainedDocumentID,
              documentIDs.contains(retainedID) else { return false }

        let excludedIDs = Set(recommendations[index].excludedDocumentIDs)
        let redundantIDs = documentIDs
            .filter { $0 != retainedID && !excludedIDs.contains($0) }
            .sorted { $0.uuidString < $1.uuidString }
        guard !redundantIDs.isEmpty else { return false }

        recommendations[index].proposedRetainedDocumentID = retainedID
        recommendations[index].proposedRedundantDocumentIDs = redundantIDs
        recommendations[index].status = .ready
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
