// 2026-07-21 11:28 SGT

import SwiftUI

struct RecommendationReviewView: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var selectedRecommendationID: String?
    let reviewArchivePlan: () -> Void
    @State private var isResetAllConfirmationPresented = false
    @State private var resetError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkflowStageBanner(
                title: "Duplicate Archival",
                subtitle: "Choose the copy to keep, then approve redundant copies for the Archive Plan."
            )
            .padding(20)
            HStack {
                Spacer()
                Button("Review Archive Plan", systemImage: "arrow.right", action: reviewArchivePlan)
                    .buttonStyle(.borderedProminent)
                    .disabled(hasPendingDecisions || scanManager.inventory.isGeneratingExecutionPlan)
            }
            .padding(.horizontal, 20).padding(.bottom, 18)
            metrics.padding(.horizontal, 20).padding(.bottom, 18)
            HStack {
                Text("DUPLICATE GROUPS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
            if let resetError {
                Label(resetError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20).padding(.bottom, 8)
            }
            if scanManager.recommendations.isEmpty {
                ContentUnavailableView(
                    "No Duplicate Groups to Review",
                    systemImage: "checklist",
                    description: Text("Scan folders to find byte-identical copies requiring a definitive selection.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(scanManager.recommendations, selection: $selectedRecommendationID) { proposal in
                    recommendationRow(proposal).tag(proposal.id)
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle("Duplicate Archival")
        .toolbar {
            Menu {
                Button("Reset All Decisions…", systemImage: "arrow.counterclockwise") {
                    isResetAllConfirmationPresented = true
                }
                .disabled(!hasReviewState || scanManager.inventory.isGeneratingExecutionPlan)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        .alert("Reset all duplicate-group decisions?", isPresented: $isResetAllConfirmationPresented) {
            Button("Reset All Decisions", role: .destructive) { Task { await resetAllDecisions() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Definitive-copy selections and decisions for every group will be reset. No files will be changed.")
        }
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            WorkflowMetricCard(value: needsSelectionCount.formatted(), label: "Needs selection", color: .orange)
            WorkflowMetricCard(value: readyCount.formatted(), label: "Ready to approve", color: .indigo)
            WorkflowMetricCard(value: approvedCount.formatted(), label: "Approved", color: .green)
        }
    }

    private func recommendationRow(_ proposal: DuplicateRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.on.doc").font(.title3).foregroundStyle(.secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(groupTitle(proposal)).font(.body.weight(.semibold)).lineLimit(1)
                Text("\(groupDocuments(for: proposal).count) byte-identical copies")
                    .font(.caption).foregroundStyle(.secondary)
                Text(proposal.decision == .approved ? "Included in Archive Plan" : "Not included in Archive Plan")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            WorkflowStatusBadge(text: displayState(proposal), color: stateColor(proposal))
        }
        .padding(.vertical, 7)
    }

    private var needsSelectionCount: Int { scanManager.recommendations.filter { $0.status == .needsSelection }.count }
    private var readyCount: Int { scanManager.recommendations.filter { $0.isReadyForApproval && $0.decision == .pending }.count }
    private var approvedCount: Int { scanManager.recommendations.filter { $0.decision == .approved }.count }
    private var hasPendingDecisions: Bool {
        scanManager.recommendations.contains { $0.decision == .pending }
    }
    private var hasReviewState: Bool {
        scanManager.recommendations.contains { scanManager.recommendationDiffersFromBaseline(id: $0.id) }
    }
    private func groupDocuments(for proposal: DuplicateRecommendation) -> [DocumentRecord] {
        scanManager.documents.filter { $0.duplicateGroupIdentifier == proposal.duplicateGroupIdentifier }
    }
    private func groupTitle(_ proposal: DuplicateRecommendation) -> String {
        groupDocuments(for: proposal).sorted { $0.filename < $1.filename }.first?.filename
            ?? "Duplicate Group \(proposal.duplicateGroupIdentifier.prefix(12))"
    }
    private func displayState(_ proposal: DuplicateRecommendation) -> String {
        proposal.decision == .pending ? proposal.status.rawValue : proposal.decision.rawValue
    }
    private func stateColor(_ proposal: DuplicateRecommendation) -> Color {
        switch proposal.decision {
        case .approved: return .green
        case .rejected: return .red
        case .postponed: return .secondary
        case .pending:
            switch proposal.status {
            case .needsSelection: return .orange
            case .readyForApproval: return .indigo
            case .failed: return .red
            }
        }
    }

    private func resetAllDecisions() async {
        do {
            try await scanManager.resetAllDecisions()
            resetError = nil
        } catch {
            resetError = error.localizedDescription
        }
    }
}
