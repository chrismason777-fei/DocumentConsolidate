// 2026-07-21 18:24 SGT

import Foundation
import Testing
@testable import DocumentConsolidate

@MainActor
struct ArchiveDestinationPresentationTests {
    @Test func successfulPlanningClearsPresentedFailure() {
        let state = ArchivePlanningState(
            plan: ExecutionPlan(id: "plan", scanSessionID: UUID(), operations: []),
            destination: nil
        )

        #expect(ArchiveDestinationPresentation.message(for: .success(state)) == nil)
    }

    @Test func lifecycleFailuresHaveActionablePresentation() {
        #expect(ArchiveDestinationPresentation.message(for: .failure(.validationFailed))?.contains("preserved") == true)
        #expect(ArchiveDestinationPresentation.message(for: .failure(.staleGeneration))?.contains("newer") == true)
        #expect(ArchiveDestinationPresentation.message(for: .failure(.cancelled))?.contains("cancelled") == true)
    }

    @Test func authorizationFailuresDistinguishUnsafeAndStaleDestinations() {
        #expect(ArchiveDestinationPresentation.message(for: .insideScanRoot).contains("outside"))
        #expect(ArchiveDestinationPresentation.message(for: .staleBookmark).contains("stale"))
        #expect(ArchiveDestinationPresentation.message(for: .scopedAccessAcquisitionFailed).contains("denied"))
    }
}
