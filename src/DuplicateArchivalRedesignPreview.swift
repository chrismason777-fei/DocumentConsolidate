// 2026-07-21 10:29 SGT

import SwiftUI

struct DuplicateArchivalRedesignPreview: View {
    @State private var stage: ProposalStage

    init(initialStage: ProposalStage = .duplicateArchival) {
        _stage = State(initialValue: initialStage)
    }

    var body: some View {
        NavigationSplitView {
            ProposalSidebar(stage: $stage)
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 250)
        } content: {
            switch stage {
            case .duplicateArchival: ProposalReviewList(stage: $stage)
            case .archivePlan: ProposalArchiveList()
            }
        } detail: {
            switch stage {
            case .duplicateArchival: ProposalReviewDetail(stage: $stage)
            case .archivePlan: ProposalArchiveDetail()
            }
        }
        .frame(minWidth: 1_080, minHeight: 700)
        .tint(.indigo)
    }
}

enum ProposalStage: String, CaseIterable, Identifiable {
    case duplicateArchival = "Duplicate Archival"
    case archivePlan = "Archive Plan"

    var id: Self { self }
}

struct ProposalSidebar: View {
    @Binding var stage: ProposalStage

    var body: some View {
        List(selection: $stage) {
            Section("Workflow") {
                ProposalStageRow(number: 1, title: "Scan Folders", status: "1 root", isComplete: true)
                ProposalStageRow(number: 2, title: "Scan", status: "Complete", isComplete: true)
                ProposalStageRow(number: 3, title: "Inventory", status: "6 files", isComplete: true)
                NavigationLink(value: ProposalStage.duplicateArchival) {
                    ProposalStageRow(number: 4, title: "Duplicate Archival", status: "1 approved · 2 to review", isComplete: false)
                }
                NavigationLink(value: ProposalStage.archivePlan) {
                    ProposalStageRow(number: 5, title: "Archive Plan", status: "Not execution-ready", isComplete: false, needsAttention: true)
                }
            }
        }
        .navigationTitle("Document Consolidate")
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Label("No files have been changed", systemImage: "lock.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
                Text("This prototype represents review and approval only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }
}

struct ProposalStageRow: View {
    let number: Int
    let title: String
    let status: String
    let isComplete: Bool
    var needsAttention = false

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(stageColor.opacity(0.13))
                Image(systemName: isComplete ? "checkmark" : "\(number).circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(stageColor)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(status).font(.caption).foregroundStyle(needsAttention ? .orange : .secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var stageColor: Color {
        if isComplete { return .green }
        return needsAttention ? .orange : .secondary
    }
}

struct ProposalStageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.indigo)
            Text(title).font(.largeTitle.weight(.bold))
            Text(subtitle).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }
}

struct ProposalMetric: View {
    let value: String
    let label: String
    let emphasis: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(emphasis)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator.opacity(0.55)))
    }
}

struct ProposalBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.11), in: Capsule())
    }
}

#Preview("Complete review journey") {
    DuplicateArchivalRedesignPreview()
}
