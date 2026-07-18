// 2026-07-18 19:03 SGT

import Foundation

struct DocumentRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let scanSessionID: UUID
    let url: URL
    let filename: String
    let fileExtension: String
    let fileSize: Int64
    let createdAt: Date?
    let modifiedAt: Date?

    init(
        id: UUID = UUID(),
        scanSessionID: UUID,
        url: URL,
        filename: String,
        fileExtension: String,
        fileSize: Int64,
        createdAt: Date?,
        modifiedAt: Date?
    ) {
        self.id = id
        self.scanSessionID = scanSessionID
        self.url = url
        self.filename = filename
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
