// 2026-07-19 16:12 SGT

import SwiftUI

struct RecommendationReviewView: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var selectedRecommendationID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageHeading("Recommendations", subtitle: "Choose retained files, generate recommendations, then approve or reject them.")
            if let session = scanManager.currentSession {
                HStack(spacing: 16) {
                    LabeledContent("Pending", value: pendingCount.formatted())
                    LabeledContent("Ready", value: readyCount.formatted())
                    LabeledContent("Accepted", value: session.acceptedRecommendationCount.formatted())
                    LabeledContent("Rejected", value: session.rejectedRecommendationCount.formatted())
                    LabeledContent("Failures", value: session.recommendationFailureCount.formatted())
                }
            }
            List(scanManager.recommendations, selection: $selectedRecommendationID) { recommendation in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Group \(recommendation.duplicateGroupIdentifier.prefix(12))")
                        Text(recommendation.status.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(recommendation.decision.rawValue)
                        .foregroundStyle(decisionColor(recommendation.decision))
                }
                .tag(recommendation.id)
            }
        }
        .padding()
        .navigationTitle("Recommendations")
    }

    private var pendingCount: Int {
        scanManager.recommendations.filter { $0.decision == .pending }.count
    }

    private var readyCount: Int {
        scanManager.recommendations.filter { $0.status == .ready }.count
    }

    private func decisionColor(_ decision: RecommendationDecision) -> Color {
        switch decision {
        case .pending: .orange
        case .accepted: .green
        case .rejected: .red
        }
    }
}
struct RecommendationDetailView: View {
    @Environment(ScanManager.self) private var scanManager
    let recommendation: DuplicateRecommendation?

    var body: some View {
        DetailShell(title: recommendation.map { "Recommendation \($0.duplicateGroupIdentifier.prefix(12))" } ?? "No recommendation selected") {
            if let recommendation {
                LabeledContent("Decision", value: recommendation.decision.rawValue)
                LabeledContent("Recommendation status", value: recommendation.status.rawValue)
                LabeledContent("Deterministic", value: recommendation.isDeterministic ? "Yes" : "No")
                Text(recommendation.rationale)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                Text("Files in this duplicate group").font(.headline)
                ForEach(groupDocuments(for: recommendation)) { document in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Label(document.filename, systemImage: roleIcon(for: document, recommendation: recommendation))
                                .foregroundStyle(roleColor(for: document, recommendation: recommendation))
                            Spacer()
                            Text(role(for: document, recommendation: recommendation).rawValue)
                                .foregroundStyle(roleColor(for: document, recommendation: recommendation))
                        }
                        Text(document.url.path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            roleButton("Retain", role: .retain, document: document, recommendation: recommendation)
                            roleButton("Consolidate", role: .consolidate, document: document, recommendation: recommendation)
                            roleButton("Exclude", role: .exclude, document: document, recommendation: recommendation)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                Divider()
                HStack {
                    Button("Generate Recommendation", systemImage: "sparkles") {
                        Task { await scanManager.generateRecommendation(id: recommendation.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canGenerate(recommendation))
                    Spacer()
                    decisionButton("Accept Recommendation", selected: recommendation.decision == .accepted, color: .green) {
                        Task { await scanManager.acceptRecommendation(id: recommendation.id) }
                    }
                    .disabled(recommendation.status != .ready)
                    decisionButton("Reject Recommendation", selected: recommendation.decision == .rejected, color: .red) {
                        Task { await scanManager.rejectRecommendation(id: recommendation.id) }
                    }
                }
                Text("Recommendation approval updates and validates the execution plan automatically. No files are changed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func groupDocuments(for recommendation: DuplicateRecommendation) -> [DocumentRecord] {
        scanManager.documents.filter { $0.duplicateGroupIdentifier == recommendation.duplicateGroupIdentifier }
            .sorted { $0.url.path < $1.url.path }
    }

    private func decisionButton(
        _ title: String,
        selected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .frame(minWidth: 72)
            .buttonStyle(.borderedProminent)
            .tint(selected ? color : .secondary.opacity(0.25))
    }

    private func roleButton(
        _ title: String,
        role: RecommendationFileRole,
        document: DocumentRecord,
        recommendation: DuplicateRecommendation
    ) -> some View {
        Button(title) {
            Task {
                await scanManager.setRecommendationFileRole(
                    recommendationID: recommendation.id,
                    documentID: document.id,
                    role: role
                )
            }
        }
        .tint(self.role(for: document, recommendation: recommendation) == role ? roleColor(role) : nil)
    }

    private func canGenerate(_ recommendation: DuplicateRecommendation) -> Bool {
        let documents = groupDocuments(for: recommendation)
        guard let retainedID = recommendation.selectedRetainedDocumentID,
              documents.contains(where: { $0.id == retainedID }) else { return false }
        let excludedIDs = Set(recommendation.excludedDocumentIDs)
        return documents.contains { $0.id != retainedID && !excludedIDs.contains($0.id) }
    }

    private func role(for document: DocumentRecord, recommendation: DuplicateRecommendation) -> RecommendationFileRole {
        if recommendation.selectedRetainedDocumentID == document.id { return .retain }
        if recommendation.excludedDocumentIDs.contains(document.id) { return .exclude }
        return .consolidate
    }

    private func roleIcon(for document: DocumentRecord, recommendation: DuplicateRecommendation) -> String {
        switch role(for: document, recommendation: recommendation) {
        case .retain: "checkmark.circle"
        case .consolidate: "arrow.triangle.merge"
        case .exclude: "minus.circle"
        }
    }

    private func roleColor(for document: DocumentRecord, recommendation: DuplicateRecommendation) -> Color {
        roleColor(role(for: document, recommendation: recommendation))
    }

    private func roleColor(_ role: RecommendationFileRole) -> Color {
        switch role {
        case .retain: .green
        case .consolidate: .blue
        case .exclude: .orange
        }
    }
}
