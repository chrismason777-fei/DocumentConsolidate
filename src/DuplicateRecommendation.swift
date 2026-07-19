// 2026-07-19 17:25 SGT

import Foundation

enum RecommendationStatus: String, Sendable {
    case needsSelection = "Needs Selection"
    case readyForApproval = "Ready for Approval"
    case failed = "Failed"
}

enum RecommendationDecision: String, Sendable {
    case pending = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
    case postponed = "Postponed"
}

struct DuplicateRecommendation: Identifiable, Equatable, Sendable {
    let id: String
    let duplicateGroupIdentifier: String
    var definitiveDocumentID: UUID?
    var redundantDocumentIDs: [UUID]
    var status: RecommendationStatus
    var rationale: String
    let isDeterministic: Bool
    var isManuallySelected = false
    var decision: RecommendationDecision = .pending

    var isReadyForApproval: Bool {
        status == .readyForApproval
            && definitiveDocumentID != nil
            && !redundantDocumentIDs.isEmpty
    }
}

struct RecommendationGenerationResult: Sendable {
    let recommendations: [DuplicateRecommendation]
    let evaluatedGroupCount: Int
    let failureCount: Int
}
