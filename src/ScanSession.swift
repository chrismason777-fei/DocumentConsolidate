// 2026-07-18 22:46 SGT

import Foundation

enum DuplicateAnalysisStatus: String, Sendable {
    case pending = "Pending"
    case complete = "Complete"
}

struct ScanSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let sourceFolders: [URL]
    var duplicateAnalysisStatus: DuplicateAnalysisStatus = .pending
    var totalDocumentCount = 0
    var uniqueDocumentCount = 0
    var duplicateDocumentCount = 0
    var duplicateGroupCount = 0

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceFolders: [URL]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceFolders = sourceFolders
    }
}
