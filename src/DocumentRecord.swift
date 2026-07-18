// 2026-07-18 20:10 SGT

import Foundation

enum DocumentAnalysisStatus: String, Sendable {
    case pending = "Pending"
    case analysing = "Analysing"
    case complete = "Complete"
    case failed = "Failed"
}

enum DocumentCategory: String, Sendable {
    case document = "Document"
    case spreadsheet = "Spreadsheet"
    case presentation = "Presentation"
    case text = "Text"
    case other = "Other"
}

struct DocumentRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let scanSessionID: UUID
    let url: URL
    let filename: String
    let fileExtension: String
    var fileSize: Int64
    var createdAt: Date?
    var modifiedAt: Date?
    var analysisStatus: DocumentAnalysisStatus
    var isSupported: Bool?
    var category: DocumentCategory?
    var displayDocumentType: String?
    var analysedAt: Date?

    init(
        id: UUID = UUID(),
        scanSessionID: UUID,
        url: URL,
        filename: String,
        fileExtension: String,
        fileSize: Int64,
        createdAt: Date?,
        modifiedAt: Date?,
        analysisStatus: DocumentAnalysisStatus = .pending,
        isSupported: Bool? = nil,
        category: DocumentCategory? = nil,
        displayDocumentType: String? = nil,
        analysedAt: Date? = nil
    ) {
        self.id = id
        self.scanSessionID = scanSessionID
        self.url = url
        self.filename = filename
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.analysisStatus = analysisStatus
        self.isSupported = isSupported
        self.category = category
        self.displayDocumentType = displayDocumentType
        self.analysedAt = analysedAt
    }
}
