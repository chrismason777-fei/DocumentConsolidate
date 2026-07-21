// 2026-07-21 11:28 SGT

import Foundation

enum RecommendationResetError: LocalizedError {
    case baselineUnavailable
    case resetConflict

    var errorDescription: String? {
        switch self {
        case .baselineUnavailable:
            "The duplicate group could not be restored because its analysed documents are no longer available."
        case .resetConflict:
            "The duplicate-group decision could not be reset because its current state changed."
        }
    }
}

extension ScanManager {
    func resetDecision(id: String) async throws {
        let baseline = try baselineRecommendation(id: id)
        guard inventory.resetRecommendation(id: id, to: baseline) else {
            throw RecommendationResetError.resetConflict
        }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func resetAllDecisions() async throws {
        let baselines = try baselineRecommendations(ids: Set(recommendations.map(\.id)))
        guard inventory.resetRecommendationReview(to: baselines) else {
            throw RecommendationResetError.resetConflict
        }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func recommendationDiffersFromBaseline(id: String) -> Bool {
        guard let recommendation = recommendations.first(where: { $0.id == id }),
              let baseline = try? baselineRecommendation(id: id) else { return false }
        return recommendation != baseline
    }

    func approveArchival(id: String, definitiveDocumentID: UUID) async {
        guard let recommendation = recommendations.first(where: { $0.id == id }) else { return }
        let documentIDs = documents
            .filter { $0.duplicateGroupIdentifier == recommendation.duplicateGroupIdentifier }
            .map(\.id)
        guard inventory.approveRecommendation(
            id: id,
            documentID: definitiveDocumentID,
            groupDocumentIDs: documentIDs
        ) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func rejectRecommendation(id: String) async {
        guard inventory.updateRecommendationDecision(id: id, decision: .rejected) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func postponeRecommendation(id: String) async {
        guard inventory.updateRecommendationDecision(id: id, decision: .postponed) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func selectDefinitiveCopy(id: String, documentID: UUID) async {
        guard let recommendation = recommendations.first(where: { $0.id == id }) else { return }
        let documentIDs = documents
            .filter { $0.duplicateGroupIdentifier == recommendation.duplicateGroupIdentifier }
            .map(\.id)
        guard inventory.selectDefinitiveCopy(id: id, documentID: documentID, groupDocumentIDs: documentIDs) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func refreshRecommendationSummary() {
        currentSession?.groupsRequiringReviewCount = recommendations.filter { $0.status == .needsSelection }.count
        currentSession?.acceptedRecommendationCount = recommendations.filter { $0.decision == .approved }.count
        currentSession?.rejectedRecommendationCount = recommendations.filter { $0.decision == .rejected }.count
    }

    private func baselineRecommendation(id: String) throws -> DuplicateRecommendation {
        guard let baseline = try baselineRecommendations(ids: Set([id])).first else {
            throw RecommendationResetError.baselineUnavailable
        }
        return baseline
    }

    private func baselineRecommendations(ids: Set<String>) throws -> [DuplicateRecommendation] {
        let groups = try ids.sorted().map { id -> DuplicateGroup in
            let groupDocuments = documents
                .filter { $0.duplicateGroupIdentifier == id }
                .sorted { $0.url.path < $1.url.path }
            guard groupDocuments.count > 1 else { throw RecommendationResetError.baselineUnavailable }
            return DuplicateGroup(identifier: id, documents: groupDocuments)
        }
        let baselines = RecommendationService().generate(from: groups).recommendations
        guard baselines.count == ids.count, Set(baselines.map(\.id)) == ids else {
            throw RecommendationResetError.baselineUnavailable
        }
        return baselines
    }
}
