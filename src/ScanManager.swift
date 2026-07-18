// 2026-07-18 19:24 SGT

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
}
