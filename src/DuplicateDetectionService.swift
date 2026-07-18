// 2026-07-18 22:46 SGT

import Foundation

struct DuplicateDetectionResult: Sendable {
    let documents: [DocumentRecord]
    let uniqueDocumentCount: Int
    let duplicateDocumentCount: Int
    let duplicateGroupCount: Int
}

struct DuplicateDetectionService: Sendable {
    func analyse(_ documents: [DocumentRecord]) -> DuplicateDetectionResult {
        let groups = Dictionary(grouping: documents.filter {
            $0.hashStatus == .complete && $0.contentHash != nil
        }) { $0.contentHash! }

        let analysedDocuments = documents.map { document in
            var analysedDocument = document
            guard document.hashStatus == .complete,
                  let contentHash = document.contentHash,
                  let group = groups[contentHash] else {
                analysedDocument.duplicateStatus = .unavailable
                return analysedDocument
            }

            analysedDocument.duplicateGroupSize = group.count
            if group.count > 1 {
                analysedDocument.duplicateStatus = .duplicate
                analysedDocument.duplicateGroupIdentifier = contentHash
            } else {
                analysedDocument.duplicateStatus = .unique
                analysedDocument.duplicateGroupIdentifier = nil
            }
            return analysedDocument
        }
        let duplicateGroups = groups.values.filter { $0.count > 1 }
        return DuplicateDetectionResult(
            documents: analysedDocuments,
            uniqueDocumentCount: groups.values.filter { $0.count == 1 }.count,
            duplicateDocumentCount: duplicateGroups.reduce(0) { $0 + $1.count },
            duplicateGroupCount: duplicateGroups.count
        )
    }
}
