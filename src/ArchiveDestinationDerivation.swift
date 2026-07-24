// 2026-07-24 20:45 SGT

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
        let sessionRoot = uniqueSessionRoot(
            in: destination.canonicalRootURL,
            baseName: sessionDirectoryName(sessionID: sessionID, createdAt: createdAt, calendar: calendar)
        )

        let initial = operations.map { operation -> PlannedOperation in
            guard let source = operation.sourceDocument else { return operation }
            let sourceURL = ArchiveDestinationPath.canonicalURL(source.url)
            let containingRoots = canonicalRoots.filter { ArchiveDestinationPath.contains(sourceURL, in: $0) }
            guard let containingRoot = containingRoots.max(by: { $0.pathComponents.count < $1.pathComponents.count }) else {
                return copy(operation, destination: nil, issues: [.sourceOutsideScanRoots])
            }

            let relativeComponents = sourceURL.pathComponents.dropFirst(containingRoot.pathComponents.count)
            let archiveComponents = [containingRoot.lastPathComponent] + relativeComponents
            guard !relativeComponents.isEmpty,
                  archiveComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0 != "/" }) else {
                return copy(operation, destination: nil, issues: [.invalidRelativePath])
            }

            let resolved = archiveComponents.reduce(sessionRoot) { partialURL, component in
                partialURL.appending(path: component)
            }
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
        formatter.dateFormat = "yyMMdd-HHmm"
        return formatter.string(from: createdAt)
    }

    private func uniqueSessionRoot(in destinationRoot: URL, baseName: String) -> URL {
        var suffix = 1
        var candidate = destinationRoot.appending(path: baseName, directoryHint: .isDirectory)
        while environment.itemExists(candidate) {
            suffix += 1
            candidate = destinationRoot.appending(path: "\(baseName)-\(suffix)", directoryHint: .isDirectory)
        }
        return candidate
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
