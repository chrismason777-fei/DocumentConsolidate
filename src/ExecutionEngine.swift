// 2026-07-24 21:08 SGT

import Foundation

enum ExecutionOutcome: String, Sendable {
    case succeeded = "Succeeded"
    case failed = "Failed"
}

struct OperationExecutionResult: Identifiable, Equatable, Sendable {
    let id: String
    let operationID: String
    let outcome: ExecutionOutcome
    let sourceURL: URL
    let destinationURL: URL?
    let archivedHash: String?
    let sourceRemoved: Bool
    let message: String
}

struct ExecutionSummary: Equatable, Sendable {
    let executionID: UUID
    let planID: String
    let scanSessionID: UUID
    let startedAt: Date
    let completedAt: Date
    let results: [OperationExecutionResult]

    var successfulOperationCount: Int { results.filter { $0.outcome == .succeeded }.count }
    var failedOperationCount: Int { results.filter { $0.outcome == .failed }.count }
}

enum ExecutionEngineError: Error, Equatable, LocalizedError, Sendable {
    case invalidPlan(String)

    var errorDescription: String? {
        switch self {
        case .invalidPlan(let message): message
        }
    }
}

struct ExecutionEngine: Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func execute(_ plan: ExecutionPlan, authorizedRoot: URL) async throws -> ExecutionSummary {
        try await preflight(plan, authorizedRoot: authorizedRoot)
        let startedAt = Date()
        var results: [OperationExecutionResult] = []

        for operation in plan.operations {
            results.append(await execute(operation, authorizedRoot: authorizedRoot))
        }

        return ExecutionSummary(
            executionID: plan.scanSessionID,
            planID: plan.id,
            scanSessionID: plan.scanSessionID,
            startedAt: startedAt,
            completedAt: Date(),
            results: results
        )
    }

    private func preflight(_ plan: ExecutionPlan, authorizedRoot: URL) async throws {
        let root = ArchiveDestinationPath.canonicalURL(authorizedRoot)
        guard plan.isReady, plan.destinationRoot == root else {
            throw ExecutionEngineError.invalidPlan("The published Archive Plan is not execution-ready.")
        }
        guard Set(plan.operations.map(\.id)).count == plan.operations.count else {
            throw ExecutionEngineError.invalidPlan("The published Archive Plan contains duplicate operation identifiers.")
        }
        let sources = plan.operations.compactMap(\.sourceDocument?.url).map(ArchiveDestinationPath.canonicalURL)
        let destinations = plan.operations.compactMap(\.destination).map(ArchiveDestinationPath.canonicalURL)
        guard Set(sources).count == sources.count, Set(destinations).count == destinations.count else {
            throw ExecutionEngineError.invalidPlan("The published Archive Plan contains conflicting operations.")
        }

        for operation in plan.operations {
            try await validate(operation, authorizedRoot: root, requireEmptyDestination: true)
        }
    }

    private func execute(
        _ operation: PlannedOperation,
        authorizedRoot: URL
    ) async -> OperationExecutionResult {
        do {
            try await validate(operation, authorizedRoot: authorizedRoot, requireEmptyDestination: true)
            guard let source = operation.sourceDocument, let destination = operation.destination else {
                throw ExecutionEngineError.invalidPlan("The operation is incomplete.")
            }
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            guard !fileManager.fileExists(atPath: destination.path) else {
                throw ExecutionEngineError.invalidPlan("The archive destination already exists.")
            }
            try fileManager.copyItem(at: source.url, to: destination)

            let freshSourceHash = try await DocumentContentHasher.hash(fileAt: source.url)
            let archivedHash = try await DocumentContentHasher.hash(fileAt: destination)
            let archivedSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard freshSourceHash == archivedHash,
                  freshSourceHash == operation.expectedHash,
                  archivedHash == operation.expectedHash,
                  Int64(archivedSize ?? -1) == source.fileSize else {
                throw ExecutionEngineError.invalidPlan("The source or archived copy failed hash or file-size verification.")
            }

            try fileManager.removeItem(at: source.url)
            return result(
                operation,
                outcome: .succeeded,
                archivedHash: archivedHash,
                sourceRemoved: true,
                message: "The redundant document was verified in the archive before its original was removed."
            )
        } catch {
            return result(
                operation,
                outcome: .failed,
                archivedHash: nil,
                sourceRemoved: false,
                message: error.localizedDescription
            )
        }
    }

    private func validate(
        _ operation: PlannedOperation,
        authorizedRoot: URL,
        requireEmptyDestination: Bool
    ) async throws {
        guard operation.type == .archiveRedundantCopy,
              operation.validationStatus == .valid,
              let source = operation.sourceDocument,
              let destination = operation.destination,
              let expectedHash = operation.expectedHash else {
            throw ExecutionEngineError.invalidPlan("An operation is not approved for execution.")
        }
        let sourceURL = ArchiveDestinationPath.canonicalURL(source.url)
        let definitiveURL = ArchiveDestinationPath.canonicalURL(operation.definitiveDocument.url)
        let destinationURL = ArchiveDestinationPath.canonicalURL(destination)
        guard sourceURL != definitiveURL,
              sourceURL != destinationURL,
              ArchiveDestinationPath.contains(destinationURL, in: authorizedRoot),
              destinationURL != authorizedRoot else {
            throw ExecutionEngineError.invalidPlan("An operation contains an unsafe filesystem path.")
        }
        guard fileManager.fileExists(atPath: sourceURL.path),
              fileManager.fileExists(atPath: definitiveURL.path) else {
            throw ExecutionEngineError.invalidPlan("A required document no longer exists.")
        }
        if requireEmptyDestination, fileManager.fileExists(atPath: destinationURL.path) {
            throw ExecutionEngineError.invalidPlan("An archive destination already exists.")
        }
        guard try await DocumentContentHasher.hash(fileAt: sourceURL) == expectedHash,
              try await DocumentContentHasher.hash(fileAt: definitiveURL) == operation.expectedDefinitiveHash else {
            throw ExecutionEngineError.invalidPlan("A document no longer matches the approved content hash.")
        }
    }

    private func result(
        _ operation: PlannedOperation,
        outcome: ExecutionOutcome,
        archivedHash: String?,
        sourceRemoved: Bool,
        message: String
    ) -> OperationExecutionResult {
        OperationExecutionResult(
            id: operation.id,
            operationID: operation.id,
            outcome: outcome,
            sourceURL: operation.sourceDocument?.url ?? URL(fileURLWithPath: "/"),
            destinationURL: operation.destination,
            archivedHash: archivedHash,
            sourceRemoved: sourceRemoved,
            message: message
        )
    }
}
