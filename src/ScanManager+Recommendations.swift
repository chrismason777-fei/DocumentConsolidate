// 2026-07-20 14:22 SGT

import Foundation

extension ScanManager {
    func resetDecisions() {
        inventory.resetRecommendationReview()
        refreshRecommendationSummary()
    }

    func approveArchival(id: String) async {
        guard recommendations.first(where: { $0.id == id })?.isReadyForApproval == true else { return }
        guard inventory.updateRecommendationDecision(id: id, decision: .approved) else { return }
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
}
