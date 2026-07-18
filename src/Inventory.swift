// 2026-07-18 18:46 SGT

import Observation

@MainActor
@Observable
final class Inventory {
    private(set) var documents: [DocumentRecord] = []

    func reset() {
        documents = []
    }
}
