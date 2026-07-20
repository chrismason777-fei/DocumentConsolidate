// 2026-07-20 14:22 SGT

import SwiftUI

struct RecommendationReviewView: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var selectedRecommendationID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageHeading("Duplicate Archival", subtitle: "Select definitive copies and approve archival of byte-identical redundant copies.")
            if let session = scanManager.currentSession {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { summary(session) }
                    VStack(alignment: .leading, spacing: 6) { summary(session) }
                }
            }
            HStack {
                Spacer()
                Button("Reset Decisions", systemImage: "arrow.counterclockwise") {
                    scanManager.resetDecisions()
                }
                .disabled(!hasReviewState)
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
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(groupTitle(proposal))
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Spacer()
                            statusBadge(displayState(proposal), color: decisionColor(proposal.decision))
                        }
                        Text("\(groupDocuments(for: proposal).count) byte-identical copies")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(proposal.decision == .approved && proposal.isReadyForApproval ? "Included in Archive Plan" : "Not included in Archive Plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(proposal.id)
                }
            }
        }
        .padding()
        .navigationTitle("Duplicate Archival")
    }

    private var readyCount: Int {
        scanManager.recommendations.filter { $0.isReadyForApproval && $0.decision == .pending }.count
    }

    private var hasReviewState: Bool {
        scanManager.executionPlan != nil || scanManager.recommendations.contains {
            $0.definitiveDocumentID != nil || $0.decision != .pending
        }
    }

    @ViewBuilder private func summary(_ session: ScanSession) -> some View {
        LabeledContent("Needs Selection", value: session.groupsRequiringReviewCount.formatted())
        LabeledContent("Ready for Approval", value: readyCount.formatted())
        LabeledContent("Approved", value: session.acceptedRecommendationCount.formatted())
        LabeledContent("Rejected", value: session.rejectedRecommendationCount.formatted())
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
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

    private func decisionColor(_ decision: RecommendationDecision) -> Color {
        switch decision {
        case .pending: .orange
        case .approved: .green
        case .rejected: .red
        case .postponed: .secondary
        }
    }
}

struct RecommendationDetailView: View {
    @Environment(ScanManager.self) private var scanManager
    let recommendation: DuplicateRecommendation?
    let reviewArchivePlan: () -> Void
    @State private var selectedDefinitiveID: UUID?

    var body: some View {
        DetailShell(title: recommendation.map(groupTitle) ?? "No duplicate group selected") {
            if let proposal = recommendation {
                groupSummary(proposal)
                Divider()
                definitiveCopy(proposal)
                Divider()
                redundantCopies(proposal)
                Divider()
                approval(proposal)
                Divider()
                safetyMessage
            }
        }
        .onAppear { selectedDefinitiveID = recommendation?.definitiveDocumentID }
        .onChange(of: recommendation?.id) { _, _ in selectedDefinitiveID = recommendation?.definitiveDocumentID }
        .onChange(of: recommendation?.definitiveDocumentID) { _, newValue in selectedDefinitiveID = newValue }
    }

    @ViewBuilder private func groupSummary(_ proposal: DuplicateRecommendation) -> some View {
        HStack {
            Label("Verified byte-identical", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Spacer()
            Text(proposal.decision == .pending ? proposal.status.rawValue : proposal.decision.rawValue)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        LabeledContent("Copies", value: groupDocuments(for: proposal).count.formatted())
        Text("Content hash: \(proposal.duplicateGroupIdentifier)")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
    }

    @ViewBuilder private func definitiveCopy(_ proposal: DuplicateRecommendation) -> some View {
        Text("Definitive Copy").font(.headline)
        if proposal.status == .needsSelection || proposal.isManuallySelected {
            Text("Select exactly one copy to remain in its current location.").foregroundStyle(.secondary)
            ForEach(groupDocuments(for: proposal)) { document in
                VStack(alignment: .leading, spacing: 3) {
                    Button {
                        selectedDefinitiveID = document.id
                    } label: {
                        Label(document.filename, systemImage: selectedDefinitiveID == document.id ? "largecircle.fill.circle" : "circle")
                            .fontWeight(selectedDefinitiveID == document.id ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Text(document.url.path(percentEncoded: false))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 3)
            }
            Button("Confirm Definitive Copy", systemImage: "checkmark.circle") {
                guard let selectedDefinitiveID else { return }
                Task { await scanManager.selectDefinitiveCopy(id: proposal.id, documentID: selectedDefinitiveID) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedDefinitiveID == nil || selectedDefinitiveID == proposal.definitiveDocumentID)
        } else if let definitive = document(id: proposal.definitiveDocumentID) {
            fileCard(definitive)
            Text("Proposed automatically from approved deterministic evidence.").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func redundantCopies(_ proposal: DuplicateRecommendation) -> some View {
        Text("Redundant Copies").font(.headline)
        let redundantIDs = selectedDefinitiveID == proposal.definitiveDocumentID
            ? proposal.redundantDocumentIDs
            : groupDocuments(for: proposal).filter { $0.id != selectedDefinitiveID }.map(\.id)
        if redundantIDs.isEmpty {
            Text("Confirm a definitive copy to prepare the archive proposal.").foregroundStyle(.secondary)
        } else {
            ForEach(redundantIDs.compactMap(document(id:))) { fileCard($0) }
        }
    }

    @ViewBuilder private func approval(_ proposal: DuplicateRecommendation) -> some View {
        HStack {
            Text("Approval").font(.headline)
            Spacer()
            Text(proposal.decision == .pending ? proposal.status.rawValue : proposal.decision.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if proposal.decision == .approved {
            Button("Review Archive Plan", action: reviewArchivePlan).buttonStyle(.borderedProminent)
        } else if proposal.isReadyForApproval {
            Button("Approve Archival") { Task { await scanManager.approveArchival(id: proposal.id) } }
                .buttonStyle(.borderedProminent)
        }
        HStack {
            Button("Reject") { Task { await scanManager.rejectRecommendation(id: proposal.id) } }
            Button("Postpone") { Task { await scanManager.postponeRecommendation(id: proposal.id) } }
        }
        .buttonStyle(.bordered)
    }

    private var safetyMessage: some View {
        Label("No files have been changed. Approval affects archive-plan eligibility only.", systemImage: "lock.shield")
            .foregroundStyle(.secondary)
    }

    private func groupDocuments(for proposal: DuplicateRecommendation) -> [DocumentRecord] {
        scanManager.documents
            .filter { $0.duplicateGroupIdentifier == proposal.duplicateGroupIdentifier }
            .sorted { $0.url.path < $1.url.path }
    }

    private func document(id: UUID?) -> DocumentRecord? { scanManager.documents.first { $0.id == id } }
    private func groupTitle(_ proposal: DuplicateRecommendation) -> String {
        groupDocuments(for: proposal).first?.filename ?? "Duplicate Group \(proposal.duplicateGroupIdentifier.prefix(12))"
    }

    private func fileCard(_ document: DocumentRecord) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(document.filename).fontWeight(.medium)
                Text(document.url.path(percentEncoded: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}
