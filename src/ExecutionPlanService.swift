// 2026-07-19 11:00 SGT

import Foundation

struct ExecutionPlanService: Sendable {
    func generate(
        recommendations: [DuplicateRecommendation],
        documents: [DocumentRecord],
        scanSessionID: UUID
    ) -> ExecutionPlan {
        let accepted = recommendations
            .filter { $0.decision == .accepted }
            .sorted { $0.id < $1.id }
        let documentsByID = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        var operations: [PlannedOperation] = []

        for recommendation in accepted {
            guard let destinationID = recommendation.proposedRetainedDocumentID,
                  let destination = documentsByID[destinationID],
                  !recommendation.proposedRedundantDocumentIDs.isEmpty else {
                operations.append(invalidPlaceholder(for: recommendation))
                continue
            }

            for sourceID in recommendation.proposedRedundantDocumentIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                let source = documentsByID[sourceID]
                operations.append(
                    PlannedOperation(
                        id: "\(recommendation.id):\(sourceID.uuidString.lowercased())",
                        type: .consolidateDuplicate,
                        sourceDocument: source,
                        destination: destination.url,
                        destinationDocumentID: destination.id,
                        reason: recommendation.rationale,
                        recommendationID: recommendation.id,
                        expectedHash: source?.contentHash,
                        expectedDestinationHash: destination.contentHash,
                        executionStatus: .notStarted,
                        validationStatus: source == nil ? .invalid : .pending,
                        validationIssues: source == nil ? ["The source document is no longer present in the inventory."] : []
                    )
                )
            }
        }

        return ExecutionPlan(
            id: accepted.map(\.id).joined(separator: "|"),
            scanSessionID: scanSessionID,
            operations: operations
        )
    }

    private func invalidPlaceholder(for recommendation: DuplicateRecommendation) -> PlannedOperation {
        PlannedOperation(
            id: "\(recommendation.id):incomplete",
            type: .consolidateDuplicate,
            sourceDocument: nil,
            destination: nil,
            destinationDocumentID: nil,
            reason: recommendation.rationale,
            recommendationID: recommendation.id,
            expectedHash: nil,
            expectedDestinationHash: nil,
            executionStatus: .notStarted,
            validationStatus: .invalid,
            validationIssues: ["The accepted recommendation does not identify a retained copy and redundant copies."]
        )
    }
}
