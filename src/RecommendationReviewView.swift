// 2026-07-19 17:25 SGT

import SwiftUI

struct RecommendationReviewView: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var selectedRecommendationID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageHeading("Duplicate Archival", subtitle: "Select definitive copies and approve archival of byte-identical redundant copies.")
            if let session = scanManager.currentSession {
                HStack(spacing: 16) {
                    LabeledContent("Needs Selection", value: session.groupsRequiringReviewCount.formatted())
                    LabeledContent("Ready", value: readyCount.formatted())
                    LabeledContent("Approved", value: session.acceptedRecommendationCount.formatted())
                    LabeledContent("Rejected", value: session.rejectedRecommendationCount.formatted())
                }
            }
            List(scanManager.recommendations, selection: $selectedRecommendationID) { proposal in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(groupTitle(proposal))
                        Spacer()
                        Text(proposal.decision.rawValue).foregroundStyle(decisionColor(proposal.decision))
                    }
                    Text("\(groupDocuments(for: proposal).count) byte-identical files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(displayState(proposal))
                        Spacer()
                        Text(proposal.decision == .approved && proposal.isReadyForApproval ? "Archive plan eligible" : "Not in archive plan")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(proposal.id)
            }
        }
        .padding()
        .navigationTitle("Duplicate Archival")
    }

    private var readyCount: Int {
        scanManager.recommendations.filter { $0.isReadyForApproval && $0.decision == .pending }.count
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
        Text("Duplicate Group Summary").font(.headline)
        LabeledContent("Identical files", value: groupDocuments(for: proposal).count.formatted())
        LabeledContent("Hash verification", value: "Verified byte-identical")
        LabeledContent("Current state", value: proposal.decision == .pending ? proposal.status.rawValue : proposal.decision.rawValue)
        Text("Content hash: \(proposal.duplicateGroupIdentifier)")
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
    }

    @ViewBuilder private func definitiveCopy(_ proposal: DuplicateRecommendation) -> some View {
        Text("Definitive Copy").font(.headline)
        if proposal.status == .needsSelection || proposal.isManuallySelected {
            Text("Select exactly one copy to remain in place.").foregroundStyle(.secondary)
            ForEach(groupDocuments(for: proposal)) { document in
                Button {
                    selectedDefinitiveID = document.id
                } label: {
                    Label(document.filename, systemImage: selectedDefinitiveID == document.id ? "largecircle.fill.circle" : "circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Text(document.url.path(percentEncoded: false)).font(.caption).foregroundStyle(.secondary)
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
        Text("Approval").font(.headline)
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
        VStack(alignment: .leading, spacing: 3) {
            Text(document.filename)
            Text(document.url.path(percentEncoded: false)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}
