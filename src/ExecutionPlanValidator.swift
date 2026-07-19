// 2026-07-19 17:25 SGT

import Foundation

struct ExecutionPlanValidator: Sendable {
    func validate(
        _ plan: ExecutionPlan,
        recommendations: [DuplicateRecommendation],
        documents: [DocumentRecord],
        currentScanSessionID: UUID?
    ) async -> ExecutionPlan {
        let approvedIDs = Set(recommendations.filter { $0.decision == .approved && $0.isReadyForApproval }.map(\.id))
        let currentDocuments = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        let conflictingIDs = conflictIdentifiers(in: plan.operations)
        var validated = plan

        for index in validated.operations.indices {
            var operation = validated.operations[index]
            var issues = operation.validationIssues

            if plan.scanSessionID != currentScanSessionID || !approvedIDs.contains(operation.recommendationID) {
                issues.append("The archive proposal is stale because the scan or approval state changed.")
            }
            if conflictingIDs.contains(operation.id) {
                issues.append("This operation conflicts with another planned operation.")
            }
            guard let source = operation.sourceDocument else {
                operation.validationStatus = .invalid
                operation.validationIssues = issues
                validated.operations[index] = operation
                continue
            }
            guard currentDocuments[source.id]?.contentHash == operation.expectedHash else {
                issues.append("The analysed document or hash is no longer current.")
                operation.validationStatus = .invalid
                operation.validationIssues = issues
                validated.operations[index] = operation
                continue
            }
            guard currentDocuments[operation.definitiveDocument.id]?.contentHash == operation.expectedDefinitiveHash else {
                issues.append("The definitive copy or its hash is no longer current.")
                operation.validationStatus = .invalid
                operation.validationIssues = issues
                validated.operations[index] = operation
                continue
            }

            if !FileManager.default.fileExists(atPath: source.url.path) {
                issues.append("The source file no longer exists.")
            } else if let expectedHash = operation.expectedHash {
                do {
                    let currentHash = try await DocumentContentHasher.hash(fileAt: source.url)
                    if currentHash != expectedHash { issues.append("The source file hash changed after analysis.") }
                } catch {
                    issues.append("The source file could not be hashed: \(error.localizedDescription)")
                }
            } else {
                issues.append("No analysed hash is available for the source file.")
            }

            if let definitive = currentDocuments[operation.definitiveDocument.id] {
                do {
                    let currentHash = try await DocumentContentHasher.hash(fileAt: definitive.url)
                    if currentHash != operation.expectedDefinitiveHash {
                        issues.append("The definitive copy hash changed after analysis.")
                    }
                } catch {
                    issues.append("The definitive copy could not be hashed: \(error.localizedDescription)")
                }
            }
            operation.validationStatus = issues.isEmpty ? .valid : .invalid
            operation.validationIssues = issues
            validated.operations[index] = operation
        }
        return validated
    }

    private func conflictIdentifiers(in operations: [PlannedOperation]) -> Set<String> {
        var sourceDestinations: [URL: Set<URL>] = [:]
        let sourceURLs = Set(operations.compactMap(\.sourceDocument?.url))
        let destinationURLs = Set(operations.compactMap(\.destination))

        for operation in operations {
            guard let source = operation.sourceDocument?.url, let destination = operation.destination else { continue }
            sourceDestinations[source, default: []].insert(destination)
        }
        return Set(operations.compactMap { operation in
            guard let source = operation.sourceDocument?.url else { return nil }
            let hasMultipleDestinations = (sourceDestinations[source]?.count ?? 0) > 1
            let chainsOperations = destinationURLs.contains(source) || operation.destination.map(sourceURLs.contains) == true
            return hasMultipleDestinations || chainsOperations ? operation.id : nil
        })
    }
}
