// 2026-07-18 21:57 SGT

import Foundation

extension ScanManager {
    func addSampleDocument() {
        guard let currentSession else { return }

        let url = URL(fileURLWithPath: "/tmp/sample-\(documents.count + 1).txt")
        let document = DocumentRecord(
            scanSessionID: currentSession.id,
            url: url,
            filename: url.lastPathComponent,
            fileExtension: url.pathExtension,
            fileSize: 1_024,
            createdAt: Date(),
            modifiedAt: Date()
        )
        addDocument(document)
    }

    func removeSampleDocument() {
        guard let document = documents.last else { return }
        removeDocument(id: document.id)
    }
}
