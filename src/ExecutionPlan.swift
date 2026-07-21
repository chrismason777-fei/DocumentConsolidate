// 2026-07-21 17:27 SGT

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

enum ArchiveDestinationDerivationIssue: Equatable, Sendable {
    case sourceOutsideScanRoots
    case invalidRelativePath
    case destinationEscapesRoot
    case duplicateDestination(URL)
    case destinationAlreadyExists(URL)
    case sourceEqualsDestination(URL)

    var message: String {
        switch self {
        case .sourceOutsideScanRoots:
            "The source is not contained in a selected scan root."
        case .invalidRelativePath:
            "A safe source-relative archive path could not be derived."
        case .destinationEscapesRoot:
            "The resolved archive path escapes the selected destination."
        case .duplicateDestination:
            "Multiple operations resolve to the same archive destination."
        case .destinationAlreadyExists:
            "An item already exists at the archive destination."
        case .sourceEqualsDestination:
            "The source and archive destination resolve to the same location."
        }
    }
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
    var destinationDerivationIssues: [ArchiveDestinationDerivationIssue] = []
}

struct ExecutionPlan: Identifiable, Equatable, Sendable {
    let id: String
    let scanSessionID: UUID
    var operations: [PlannedOperation]
    let destinationRoot: URL?
    let decisionRevision: Int
    let createdAt: Date

    init(
        id: String,
        scanSessionID: UUID,
        operations: [PlannedOperation],
        destinationRoot: URL? = nil,
        decisionRevision: Int = 0,
        createdAt: Date = .distantPast
    ) {
        self.id = id
        self.scanSessionID = scanSessionID
        self.operations = operations
        self.destinationRoot = destinationRoot
        self.decisionRevision = decisionRevision
        self.createdAt = createdAt
    }

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
