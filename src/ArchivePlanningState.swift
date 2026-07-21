// 2026-07-21 16:46 SGT

import Foundation

struct ArchivePlanningState: Equatable, Sendable {
    let plan: ExecutionPlan
    let destination: ArchiveDestination?
}
