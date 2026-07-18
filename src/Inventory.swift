// 2026-07-18 19:14 SGT

import Foundation
import Observation

@MainActor
@Observable
final class Inventory {
    private(set) var scanSessionID: UUID?
    private(set) var documents: [DocumentRecord] = []

    @discardableResult
    func add(_ document: DocumentRecord) -> Bool {
        let canonicalURL = document.url.standardizedFileURL.resolvingSymlinksInPath()
        guard !documents.contains(where: {
            $0.id == document.id
                || $0.url.standardizedFileURL.resolvingSymlinksInPath() == canonicalURL
        }) else {
            return false
        }

        documents.append(document)
        return true
    }

    func remove(id: UUID) {
        documents.removeAll { $0.id == id }
    }

    func clear() {
        documents.removeAll()
    }

    func replace(with documents: [DocumentRecord]) {
        self.documents = documents
    }

    func reset(for scanSessionID: UUID?) {
        self.scanSessionID = scanSessionID
        clear()
    }
}
