// 2026-07-19 17:25 SGT

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

            let documents = group.documents.sorted { $0.url.path < $1.url.path }
            let evidencedCopies = documents.filter(\.hasApprovedDefinitiveCopyEvidence)
            let definitiveDocument = evidencedCopies.count == 1 ? evidencedCopies.first : nil
            recommendations.append(
                DuplicateRecommendation(
                    id: group.identifier,
                    duplicateGroupIdentifier: group.identifier,
                    definitiveDocumentID: definitiveDocument?.id,
                    redundantDocumentIDs: definitiveDocument.map { definitive in
                        documents.filter { $0.id != definitive.id }.map(\.id)
                    } ?? [],
                    status: definitiveDocument == nil ? .needsSelection : .readyForApproval,
                    rationale: rationale(evidencedCopyCount: evidencedCopies.count),
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

    private func rationale(evidencedCopyCount: Int) -> String {
        if evidencedCopyCount == 1 {
            return "Every file has the same content hash, and approved evidence identifies exactly one definitive copy. Every other byte-identical file is a redundant archive candidate."
        }
        if evidencedCopyCount > 1 {
            return "Every file has the same content hash, but approved evidence identifies more than one possible definitive copy. Select exactly one definitive copy."
        }
        return "Every file has the same content hash, but no approved deterministic rule identifies one definitive copy. Select exactly one definitive copy."
    }
}
