// 2026-07-18 23:05 SGT

import Foundation

enum RecommendationStatus: String, Sendable {
    case ready = "Ready"
    case requiresReview = "Requires Review"
    case failed = "Failed"
}

enum RecommendationDecision: String, Sendable {
    case pending = "Pending"
    case accepted = "Accepted"
    case rejected = "Rejected"
}

enum RecommendationFileRole: String, Sendable {
    case retain = "Retain"
    case consolidate = "Consolidate"
    case exclude = "Exclude"
}

struct DuplicateRecommendation: Identifiable, Equatable, Sendable {
    let id: String
    let duplicateGroupIdentifier: String
    var selectedRetainedDocumentID: UUID?
    var excludedDocumentIDs: [UUID]
    var proposedRetainedDocumentID: UUID?
    var proposedRedundantDocumentIDs: [UUID]
    var status: RecommendationStatus
    let rationale: String
    let isDeterministic: Bool
    var decision: RecommendationDecision = .pending
}

struct RecommendationGenerationResult: Sendable {
    let recommendations: [DuplicateRecommendation]
    let evaluatedGroupCount: Int
    let failureCount: Int
}
