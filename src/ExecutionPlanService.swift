// 2026-07-19 17:25 SGT

import Foundation

struct ExecutionPlanService: Sendable {
    func generate(
        recommendations: [DuplicateRecommendation],
        documents: [DocumentRecord],
        scanSessionID: UUID
    ) -> ExecutionPlan {
        let approved = recommendations
            .filter { $0.decision == .approved && $0.isReadyForApproval }
            .sorted { $0.id < $1.id }
        let documentsByID = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        var operations: [PlannedOperation] = []

        for recommendation in approved {
            guard let definitiveID = recommendation.definitiveDocumentID,
                  let definitive = documentsByID[definitiveID],
                  definitive.contentHash == recommendation.duplicateGroupIdentifier else { continue }

            for sourceID in recommendation.redundantDocumentIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                let source = documentsByID[sourceID]
                operations.append(
                    PlannedOperation(
                        id: "\(recommendation.id):\(sourceID.uuidString.lowercased())",
                        type: .archiveRedundantCopy,
                        sourceDocument: source,
                        destination: nil,
                        definitiveDocument: definitive,
                        reason: "Byte-identical duplicate of definitive copy \(definitive.filename).",
                        recommendationID: recommendation.id,
                        expectedHash: source?.contentHash,
                        expectedDefinitiveHash: definitive.contentHash ?? recommendation.duplicateGroupIdentifier,
                        executionStatus: .notStarted,
                        validationStatus: source == nil ? .invalid : .pending,
                        validationIssues: source == nil ? ["The source document is no longer present in the inventory."] : []
                    )
                )
            }
        }

        return ExecutionPlan(
            id: approved.map(\.id).joined(separator: "|"),
            scanSessionID: scanSessionID,
            operations: operations
        )
    }

}
