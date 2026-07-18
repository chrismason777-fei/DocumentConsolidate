// 2026-07-18 19:00 SGT

import Foundation
import Observation

@MainActor
@Observable
final class ScanManager {
    private(set) var currentSession: ScanSession?
    let inventory: Inventory

    init(inventory: Inventory) {
        self.inventory = inventory
    }

    var documents: [DocumentRecord] {
        inventory.documents
    }

    @discardableResult
    func createSession(for sourceFolders: [URL] = []) -> ScanSession {
        let session = ScanSession(sourceFolders: sourceFolders)
        inventory.reset(for: session.id)
        currentSession = session
        return session
    }

    func resetSession() {
        currentSession = nil
        inventory.reset(for: nil)
    }

    @discardableResult
    func addDocument(_ document: DocumentRecord) -> Bool {
        inventory.add(document)
    }

    func removeDocument(id: UUID) {
        inventory.remove(id: id)
    }

    func clearDocuments() {
        inventory.clear()
    }

    func addSampleDocument() {
        guard let currentSession else { return }

        let document = DocumentRecord(
            scanSessionID: currentSession.id,
            url: URL(fileURLWithPath: "/tmp/sample-\(documents.count + 1).txt"),
            fileSize: 1_024,
            modifiedAt: Date()
        )
        addDocument(document)
    }

    func removeSampleDocument() {
        guard let document = documents.last else { return }
        removeDocument(id: document.id)
    }
}
