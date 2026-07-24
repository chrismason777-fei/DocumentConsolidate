// 2026-07-24 16:42 SGT

import Foundation

struct ArchiveDestinationDerivation: Sendable {
    struct Environment: Sendable {
        let itemExists: @Sendable (URL) -> Bool

        static let live = Environment(
            itemExists: { FileManager.default.fileExists(atPath: $0.path) }
        )
    }

    private let environment: Environment

    init(environment: Environment = .live) {
        self.environment = environment
    }

    func derive(
        operations: [PlannedOperation],
        scanRoots: [URL],
        destination: ArchiveDestination,
        sessionID: UUID,
        createdAt: Date,
        calendar: Calendar
    ) -> [PlannedOperation] {
        let canonicalRoots = scanRoots.map(ArchiveDestinationPath.canonicalURL)
        let sessionRoot = destination.canonicalRootURL
            .appending(path: "Document Consolidate", directoryHint: .isDirectory)
            .appending(path: sessionDirectoryName(sessionID: sessionID, createdAt: createdAt, calendar: calendar), directoryHint: .isDirectory)

        let initial = operations.map { operation -> PlannedOperation in
            guard let source = operation.sourceDocument else { return operation }
            let sourceURL = ArchiveDestinationPath.canonicalURL(source.url)
            let containingRoots = canonicalRoots.filter { ArchiveDestinationPath.contains(sourceURL, in: $0) }
            guard containingRoots.max(by: { $0.pathComponents.count < $1.pathComponents.count }) != nil else {
                return copy(operation, destination: nil, issues: [.sourceOutsideScanRoots])
            }

            let archiveFilename = sourceURL.lastPathComponent
            guard !archiveFilename.isEmpty,
                  archiveFilename != ".",
                  archiveFilename != "..",
                  archiveFilename != "/" else {
                return copy(operation, destination: nil, issues: [.invalidRelativePath])
            }

            let resolved = sessionRoot.appending(path: archiveFilename)
            let canonicalDestination = ArchiveDestinationPath.canonicalURL(resolved)
            var issues: [ArchiveDestinationDerivationIssue] = []
            if !ArchiveDestinationPath.contains(canonicalDestination, in: destination.canonicalRootURL) {
                issues.append(.destinationEscapesRoot)
            }
            if canonicalDestination == sourceURL {
                issues.append(.sourceEqualsDestination(canonicalDestination))
            }
            if environment.itemExists(canonicalDestination) {
                issues.append(.destinationAlreadyExists(canonicalDestination))
            }
            return copy(operation, destination: canonicalDestination, issues: issues)
        }

        let destinations = Dictionary(grouping: initial.compactMap(\.destination), by: { $0 })
        let duplicates = Set(destinations.filter { $0.value.count > 1 }.map(\.key))
        return initial.map { operation in
            guard let destination = operation.destination, duplicates.contains(destination) else { return operation }
            return copy(
                operation,
                destination: destination,
                issues: operation.destinationDerivationIssues + [.duplicateDestination(destination)]
            )
        }
    }

    func sessionDirectoryName(sessionID: UUID, createdAt: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return "\(formatter.string(from: createdAt)) - \(sessionID.uuidString.prefix(6).uppercased())"
    }

    private func copy(
        _ operation: PlannedOperation,
        destination: URL?,
        issues: [ArchiveDestinationDerivationIssue]
    ) -> PlannedOperation {
        PlannedOperation(
            id: operation.id,
            type: operation.type,
            sourceDocument: operation.sourceDocument,
            destination: destination,
            definitiveDocument: operation.definitiveDocument,
            reason: operation.reason,
            recommendationID: operation.recommendationID,
            expectedHash: operation.expectedHash,
            expectedDefinitiveHash: operation.expectedDefinitiveHash,
            executionStatus: operation.executionStatus,
            validationStatus: issues.isEmpty ? operation.validationStatus : .invalid,
            validationIssues: operation.validationIssues + issues.map(\.message),
            destinationDerivationIssues: issues
        )
    }
}
