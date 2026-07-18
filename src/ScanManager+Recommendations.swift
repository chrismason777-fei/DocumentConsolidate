// 2026-07-18 23:05 SGT

extension ScanManager {
    func acceptRecommendation(id: String) {
        inventory.updateRecommendationDecision(id: id, decision: .accepted)
        refreshRecommendationSummary()
    }

    func rejectRecommendation(id: String) {
        inventory.updateRecommendationDecision(id: id, decision: .rejected)
        refreshRecommendationSummary()
    }
}
