// 2026-07-19 17:25 SGT

import Foundation

enum ExecutionOperationType: String, Sendable {
    case archiveRedundantCopy = "Archive Redundant Copy"
}

enum ExecutionStatus: String, Sendable {
    case notStarted = "Not Started"
}

enum OperationValidationStatus: String, Sendable {
    case pending = "Pending"
    case valid = "Valid"
    case invalid = "Invalid"
}

struct PlannedOperation: Identifiable, Equatable, Sendable {
    let id: String
    let type: ExecutionOperationType
    let sourceDocument: DocumentRecord?
    let destination: URL?
    let definitiveDocument: DocumentRecord
    let reason: String
    let recommendationID: String
    let expectedHash: String?
    let expectedDefinitiveHash: String
    let executionStatus: ExecutionStatus
    var validationStatus: OperationValidationStatus
    var validationIssues: [String]
}

struct ExecutionPlan: Identifiable, Equatable, Sendable {
    let id: String
    let scanSessionID: UUID
    var operations: [PlannedOperation]

    var validOperationCount: Int { operations.filter { $0.validationStatus == .valid }.count }
    var invalidOperationCount: Int { operations.filter { $0.validationStatus == .invalid }.count }
    var pendingOperationCount: Int { operations.filter { $0.validationStatus == .pending }.count }
    var isReady: Bool {
        !operations.isEmpty
            && operations.allSatisfy { $0.destination != nil }
            && invalidOperationCount == 0
            && pendingOperationCount == 0
    }
}
