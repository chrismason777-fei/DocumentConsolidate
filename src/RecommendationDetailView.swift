// 2026-07-21 12:02 SGT

import AppKit
import QuickLook
import SwiftUI

struct RecommendationDetailView: View {
    @Environment(ScanManager.self) private var scanManager
    let recommendation: DuplicateRecommendation?
    @State private var selectedDefinitiveID: UUID?
    @State private var quickLookURL: URL?
    @State private var resetError: String?

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
                                action: { select(document.id, for: proposal) }
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
                    consequence
                    Divider()
                    decisionControls(proposal)
                    if let resetError {
                        Label(resetError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
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
        .onChange(of: recommendation?.id) { _, _ in
            selectedDefinitiveID = recommendation?.definitiveDocumentID
            resetError = nil
        }
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

    private var consequence: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "archivebox.fill").font(.title3).foregroundStyle(.indigo).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text("What happens next").font(.headline)
                Text("Approval adds the ARCHIVE copies to the Archive Plan. No file moves during review or approval.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func decisionControls(_ proposal: DuplicateRecommendation) -> some View {
        Text("GROUP DECISION").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                decisionButtons(proposal)
            }
            VStack(spacing: 10) {
                decisionButtons(proposal)
            }
        }
        if scanManager.recommendationDiffersFromBaseline(id: proposal.id) {
            Divider()
            Button("Reset This Group", systemImage: "arrow.counterclockwise") {
                Task { await resetGroup(id: proposal.id) }
            }
            .buttonStyle(.bordered)
            .disabled(scanManager.inventory.isGeneratingExecutionPlan)
        }
    }

    @ViewBuilder private func decisionButtons(_ proposal: DuplicateRecommendation) -> some View {
        decisionButton("Approve", icon: "checkmark.circle.fill", decision: .approved, color: .green, proposal: proposal) {
            guard let selectedDefinitiveID, proposal.decision != .approved else { return }
            Task { await scanManager.approveArchival(id: proposal.id, definitiveDocumentID: selectedDefinitiveID) }
        }
        .disabled(selectedDefinitiveID == nil)
        decisionButton("Reject", icon: "xmark.circle.fill", decision: .rejected, color: .red, proposal: proposal) {
            Task { await scanManager.rejectRecommendation(id: proposal.id) }
        }
        decisionButton("Postpone", icon: "clock.fill", decision: .postponed, color: .orange, proposal: proposal) {
            Task { await scanManager.postponeRecommendation(id: proposal.id) }
        }
    }

    private func decisionButton(
        _ title: String,
        icon: String,
        decision: RecommendationDecision,
        color: Color,
        proposal: DuplicateRecommendation,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = proposal.decision == decision
        return Button(action: action) {
            Label(title, systemImage: icon)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 26)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? color : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? color : Color(nsColor: .separatorColor)))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ documentID: UUID, for proposal: DuplicateRecommendation) {
        guard selectedDefinitiveID != documentID else { return }
        selectedDefinitiveID = documentID
        if proposal.decision != .pending {
            Task { await scanManager.selectDefinitiveCopy(id: proposal.id, documentID: documentID) }
        }
    }

    private func groupDocuments(for proposal: DuplicateRecommendation) -> [DocumentRecord] {
        scanManager.documents.filter { $0.duplicateGroupIdentifier == proposal.duplicateGroupIdentifier }.sorted { $0.url.path < $1.url.path }
    }

    private func groupTitle(_ proposal: DuplicateRecommendation) -> String {
        groupDocuments(for: proposal).first?.filename ?? "Duplicate Group \(proposal.duplicateGroupIdentifier.prefix(12))"
    }

    private func resetGroup(id: String) async {
        do {
            try await scanManager.resetDecision(id: id)
            resetError = nil
        } catch {
            resetError = error.localizedDescription
        }
    }
}
