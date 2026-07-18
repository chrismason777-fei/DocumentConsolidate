// 2026-07-18 19:24 SGT

import Foundation
import Observation

@MainActor
@Observable
final class Inventory {
    private(set) var scanSessionID: UUID?
    private(set) var documents: [DocumentRecord] = []

    func reset(for scanSessionID: UUID?) {
        self.scanSessionID = scanSessionID
        documents = []
    }
}
