// 2026-07-19 16:55 SGT

import Foundation

extension ScanManager {
    func acceptRecommendation(id: String) async {
        guard recommendations.first(where: { $0.id == id })?.status == .ready else { return }
        guard inventory.updateRecommendationDecision(id: id, decision: .accepted) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func rejectRecommendation(id: String) async {
        guard inventory.updateRecommendationDecision(id: id, decision: .rejected) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func setRecommendationFileRole(
        recommendationID: String,
        documentID: UUID,
        role: RecommendationFileRole
    ) async {
        guard inventory.updateRecommendationFileRole(
            id: recommendationID,
            documentID: documentID,
            role: role
        ) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func generateRecommendation(id: String) async {
        guard let recommendation = recommendations.first(where: { $0.id == id }) else { return }
        let documentIDs = documents
            .filter { $0.duplicateGroupIdentifier == recommendation.duplicateGroupIdentifier }
            .map(\.id)
        guard inventory.generateRecommendation(id: id, documentIDs: documentIDs) else { return }
        refreshRecommendationSummary()
        await generateExecutionPlan()
    }

    func refreshRecommendationSummary() {
        currentSession?.groupsRequiringReviewCount = recommendations.filter { $0.status == .requiresReview }.count
        currentSession?.acceptedRecommendationCount = recommendations.filter { $0.decision == .accepted }.count
        currentSession?.rejectedRecommendationCount = recommendations.filter { $0.decision == .rejected }.count
    }
}
