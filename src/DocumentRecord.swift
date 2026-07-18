// 2026-07-18 18:46 SGT

import Foundation

struct DocumentRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let scanSessionID: UUID
    let url: URL
    let fileSize: Int64
    let modifiedAt: Date?

    init(
        id: UUID = UUID(),
        scanSessionID: UUID,
        url: URL,
        fileSize: Int64,
        modifiedAt: Date?
    ) {
        self.id = id
        self.scanSessionID = scanSessionID
        self.url = url
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
    }
}
