// 2026-07-18 23:05 SGT

import Foundation

struct RecommendationService: Sendable {
    func generate(from groups: [DuplicateGroup]) -> RecommendationGenerationResult {
        var recommendations: [DuplicateRecommendation] = []
        var failureCount = 0

        for group in groups.sorted(by: { $0.identifier < $1.identifier }) {
            guard group.documents.count > 1,
                  group.documents.allSatisfy({
                      $0.duplicateStatus == .duplicate
                          && $0.duplicateGroupIdentifier == group.identifier
                          && $0.hashStatus == .complete
                          && $0.contentHash == group.identifier
                  }) else {
                failureCount += 1
                continue
            }

            recommendations.append(
                DuplicateRecommendation(
                    id: group.identifier,
                    duplicateGroupIdentifier: group.identifier,
                    selectedRetainedDocumentID: nil,
                    excludedDocumentIDs: [],
                    proposedRetainedDocumentID: nil,
                    proposedRedundantDocumentIDs: [],
                    status: .requiresReview,
                    rationale: "No approved retained-copy selection policy is defined. Review this duplicate group and choose a retained copy manually in a later approved milestone.",
                    isDeterministic: true
                )
            )
        }

        return RecommendationGenerationResult(
            recommendations: recommendations,
            evaluatedGroupCount: groups.count,
            failureCount: failureCount
        )
    }
}
