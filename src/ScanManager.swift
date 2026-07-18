// 2026-07-18 18:46 SGT

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
    func createSession(for sourceFolders: [URL]) -> ScanSession {
        let session = ScanSession(sourceFolders: sourceFolders)
        inventory.reset()
        currentSession = session
        return session
    }
}
