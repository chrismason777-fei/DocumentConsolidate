// 2026-07-20 19:39 SGT

import SwiftUI

struct ProposalReviewList: View {
    @Binding var stage: ProposalStage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProposalStageHeader(
                eyebrow: "STAGE 5 OF 6",
                title: "Duplicate Archival",
                subtitle: "Choose the copy to keep, then approve redundant copies for archival."
            )
            HStack(spacing: 10) {
                ProposalMetric(value: "1", label: "Needs selection", emphasis: .orange)
                ProposalMetric(value: "1", label: "Ready to approve", emphasis: .indigo)
                ProposalMetric(value: "1", label: "Approved", emphasis: .green)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            HStack {
                Text("DUPLICATE GROUPS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Reset Decisions", systemImage: "arrow.counterclockwise") { }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            List {
                ProposalReviewRow(title: "GroupA-original.txt", copies: 2, state: "Approved", color: .green, selected: true)
                ProposalReviewRow(title: "similar-to-unique.txt", copies: 2, state: "Needs selection", color: .orange)
                ProposalReviewRow(title: "GroupB-original.txt", copies: 2, state: "Ready to approve", color: .indigo)
            }
            .listStyle(.inset)

            Button("Continue to Archive Plan", systemImage: "arrow.right") { stage = .archivePlan }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationSplitViewColumnWidth(min: 390, ideal: 440, max: 520)
    }
}

struct ProposalReviewRow: View {
    let title: String
    let copies: Int
    let state: String
    let color: Color
    var selected = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.on.doc").font(.title3).foregroundStyle(selected ? .indigo : .secondary).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.semibold))
                Text("\(copies) byte-identical copies").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ProposalBadge(text: state, color: color)
        }
        .padding(.vertical, 7)
        .listRowBackground(selected ? Color.indigo.opacity(0.08) : Color.clear)
    }
}

struct ProposalReviewDetail: View {
    @Binding var stage: ProposalStage
    @State private var selectedCopy = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("GroupA-original.txt").font(.title.weight(.bold))
                        Text("Two copies contain exactly the same data.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    ProposalBadge(text: "Approved", color: .green)
                }
                ProposalReviewCallout(
                    icon: "checkmark.circle.fill",
                    title: "Definitive copy confirmed",
                    message: "This copy stays in its current location and remains authoritative."
                )
                VStack(spacing: 10) {
                    ProposalFileChoice(name: "GroupA-original.txt", path: "~/Verification/GroupA-original.txt", outcome: "KEEP", selected: selectedCopy == 0) { selectedCopy = 0 }
                    ProposalFileChoice(name: "GroupA-copy.txt", path: "~/Verification/GroupA-copy.txt", outcome: "ARCHIVE", selected: selectedCopy == 1) { selectedCopy = 1 }
                }
                Button("Confirm Definitive Copy", systemImage: "checkmark.circle.fill") { }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Divider()
                ProposalReviewCallout(
                    icon: "archivebox.fill",
                    title: "What happens next",
                    message: "The redundant copy becomes eligible for the Archive Plan. No file moves at this stage."
                )
                Button("Review Archive Plan", systemImage: "arrow.right", action: { stage = .archivePlan })
                    .buttonStyle(.bordered)
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .navigationSplitViewColumnWidth(min: 420, ideal: 520)
    }
}

struct ProposalReviewCallout: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(.indigo).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(message).foregroundStyle(.secondary)
            }
        }
    }
}

struct ProposalFileChoice: View {
    let name: String
    let path: String
    let outcome: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3).foregroundStyle(selected ? .indigo : .secondary)
                Image(systemName: outcome == "KEEP" ? "doc.badge.checkmark.fill" : "archivebox.fill")
                    .foregroundStyle(outcome == "KEEP" ? .indigo : .orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).fontWeight(.semibold)
                    Text(path).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(outcome)
                    .font(.caption2.weight(.bold)).tracking(0.8)
                    .foregroundStyle(outcome == "KEEP" ? .indigo : .orange)
            }
            .padding(14)
            .contentShape(Rectangle())
            .background(selected ? Color.indigo.opacity(0.08) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.indigo : Color(nsColor: .separatorColor).opacity(0.5), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}
