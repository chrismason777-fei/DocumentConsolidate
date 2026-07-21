// 2026-07-21 10:05 SGT

import AppKit
import QuickLook
import SwiftUI

struct RecommendationReviewView: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var selectedRecommendationID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkflowStageBanner(
                stage: "STAGE 5 OF 6",
                title: "Duplicate Archival",
                subtitle: "Choose the copy to keep, then approve redundant copies for the Archive Plan."
            )
            .padding(20)
            metrics.padding(.horizontal, 20).padding(.bottom, 18)
            HStack {
                Text("DUPLICATE GROUPS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Reset Decisions", systemImage: "arrow.counterclockwise") { scanManager.resetDecisions() }
                    .buttonStyle(.plain).foregroundStyle(.secondary).disabled(!hasReviewState)
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
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
    private var hasReviewState: Bool {
        scanManager.executionPlan != nil || scanManager.recommendations.contains { $0.definitiveDocumentID != nil || $0.decision != .pending }
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
}

struct RecommendationDetailView: View {
    @Environment(ScanManager.self) private var scanManager
    let recommendation: DuplicateRecommendation?
    let reviewArchivePlan: () -> Void
    @State private var selectedDefinitiveID: UUID?
    @State private var quickLookURL: URL?

    var body: some View {
        ScrollView {
            if let proposal = recommendation {
                VStack(alignment: .leading, spacing: 22) {
                    detailHeader(proposal)
                    Label("Duplicate contents verified", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                    Text("CHOOSE THE DEFINITIVE COPY").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    Text("The KEEP copy remains in its current location. Every other copy is proposed for ARCHIVE.")
                        .foregroundStyle(.secondary)
                    ForEach(groupDocuments(for: proposal)) { document in
                        VStack(alignment: .leading, spacing: 8) {
                            WorkflowOutcomeCard(
                                outcome: selectedDefinitiveID == document.id ? "KEEP" : "ARCHIVE",
                                document: document,
                                color: selectedDefinitiveID == document.id ? .indigo : .orange,
                                isSelected: selectedDefinitiveID == document.id,
                                action: canChoose(proposal) ? { selectedDefinitiveID = document.id } : nil
                            )
                            HStack {
                                Button("Quick Look", systemImage: "eye") { quickLookURL = document.url }
                                Button("Reveal in Finder", systemImage: "folder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([document.url])
                                }
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading, 14)
                        }
                    }
                    Text("Recommendation: \(proposal.rationale)")
                        .font(.caption).foregroundStyle(.secondary)
                    confirmation(proposal)
                    consequence(proposal)
                    Divider()
                    approval(proposal)
                    Label("No files have been changed. Approval affects Archive Plan eligibility only.", systemImage: "lock.shield.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(28).frame(maxWidth: 700, alignment: .leading)
            } else {
                ContentUnavailableView("No duplicate group selected", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity, minHeight: 420)
            }
        }
        .onAppear { selectedDefinitiveID = recommendation?.definitiveDocumentID }
        .onChange(of: recommendation?.id) { _, _ in selectedDefinitiveID = recommendation?.definitiveDocumentID }
        .onChange(of: recommendation?.definitiveDocumentID) { _, value in selectedDefinitiveID = value }
        .quickLookPreview($quickLookURL)
    }

    private func detailHeader(_ proposal: DuplicateRecommendation) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(groupTitle(proposal)).font(.title.weight(.bold))
                Text("\(groupDocuments(for: proposal).count) copies contain exactly the same data.").foregroundStyle(.secondary)
            }
            Spacer()
            WorkflowStatusBadge(text: proposal.decision == .pending ? proposal.status.rawValue : proposal.decision.rawValue, color: proposal.decision == .approved ? .green : .orange)
        }
    }

    @ViewBuilder private func confirmation(_ proposal: DuplicateRecommendation) -> some View {
        if canChoose(proposal) {
            Button("Confirm Definitive Copy", systemImage: "checkmark.circle.fill") {
                guard let selectedDefinitiveID else { return }
                Task { await scanManager.selectDefinitiveCopy(id: proposal.id, documentID: selectedDefinitiveID) }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(selectedDefinitiveID == nil || selectedDefinitiveID == proposal.definitiveDocumentID)
        }
    }

    private func consequence(_ proposal: DuplicateRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "archivebox.fill").font(.title3).foregroundStyle(.indigo).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text("What happens next").font(.headline)
                Text(proposal.isReadyForApproval
                     ? "Approval adds the ARCHIVE copies to the Archive Plan. No file moves during review or approval."
                     : "Confirm one KEEP copy to prepare the archive proposal. No file moves at this stage.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func approval(_ proposal: DuplicateRecommendation) -> some View {
        Text("APPROVAL").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
        if proposal.decision == .approved {
            Button("Review Archive Plan", systemImage: "arrow.right", action: reviewArchivePlan)
                .buttonStyle(.borderedProminent).controlSize(.large)
        } else if proposal.isReadyForApproval {
            Button("Approve Archival", systemImage: "checkmark.circle.fill") { Task { await scanManager.approveArchival(id: proposal.id) } }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        HStack {
            Button("Reject") { Task { await scanManager.rejectRecommendation(id: proposal.id) } }
            Button("Postpone") { Task { await scanManager.postponeRecommendation(id: proposal.id) } }
        }
        .buttonStyle(.bordered)
    }

    private func canChoose(_ proposal: DuplicateRecommendation) -> Bool { proposal.status == .needsSelection || proposal.isManuallySelected }
    private func groupDocuments(for proposal: DuplicateRecommendation) -> [DocumentRecord] {
        scanManager.documents.filter { $0.duplicateGroupIdentifier == proposal.duplicateGroupIdentifier }.sorted { $0.url.path < $1.url.path }
    }
    private func groupTitle(_ proposal: DuplicateRecommendation) -> String {
        groupDocuments(for: proposal).first?.filename ?? "Duplicate Group \(proposal.duplicateGroupIdentifier.prefix(12))"
    }
}
