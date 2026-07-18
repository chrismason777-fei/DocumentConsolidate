// 2026-07-18 23:05 SGT

import SwiftUI

struct RecommendationReviewView: View {
    @Environment(ScanManager.self) private var scanManager

    var body: some View {
        if let session = scanManager.currentSession,
           session.recommendationPhaseStatus == .complete {
            GroupBox("Duplicate recommendations") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No files have been changed. Decisions recorded here do not perform file operations.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack {
                        LabeledContent("Evaluated", value: session.evaluatedDuplicateGroupCount.formatted())
                        LabeledContent("Generated", value: session.generatedRecommendationCount.formatted())
                        LabeledContent("Needs review", value: session.groupsRequiringReviewCount.formatted())
                        LabeledContent("Accepted", value: session.acceptedRecommendationCount.formatted())
                        LabeledContent("Rejected", value: session.rejectedRecommendationCount.formatted())
                        LabeledContent("Failures", value: session.recommendationFailureCount.formatted())
                    }

                    ForEach(scanManager.recommendations) { recommendation in
                        DisclosureGroup("Group \(recommendation.duplicateGroupIdentifier.prefix(12)) · \(recommendation.status.rawValue) · \(recommendation.decision.rawValue)") {
                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent("Proposed retained copy") {
                                    Text(documentName(id: recommendation.proposedRetainedDocumentID) ?? "Requires user review")
                                }
                                LabeledContent("Proposed redundant copies") {
                                    Text(redundantDocumentNames(for: recommendation))
                                }
                                LabeledContent("Deterministic", value: recommendation.isDeterministic ? "Yes" : "No")
                                Text(recommendation.rationale)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button("Accept") {
                                        scanManager.acceptRecommendation(id: recommendation.id)
                                    }
                                    Button("Reject") {
                                        scanManager.rejectRecommendation(id: recommendation.id)
                                    }
                                }
                            }
                            .padding(.leading)
                        }
                    }
                }
            }
        }
    }

    private func documentName(id: UUID?) -> String? {
        guard let id else { return nil }
        return scanManager.documents.first(where: { $0.id == id })?.filename
    }

    private func redundantDocumentNames(for recommendation: DuplicateRecommendation) -> String {
        let names = recommendation.proposedRedundantDocumentIDs.compactMap { documentName(id: $0) }
        return names.isEmpty ? "None proposed until retained copy is reviewed" : names.joined(separator: ", ")
    }
}
