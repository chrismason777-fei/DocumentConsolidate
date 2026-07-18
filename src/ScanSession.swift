// 2026-07-18 18:46 SGT

import Foundation

struct ScanSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let sourceFolders: [URL]

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
