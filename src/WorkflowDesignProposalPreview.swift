// 2026-07-19 14:07 SGT

import SwiftUI

/// Non-production UI/UX proposal preview for the post-Milestone 9 workflow.
struct WorkflowDesignProposalPreview: View {
    @State private var sample: WorkflowProposalSample
    @State private var selectedStage: WorkflowProposalStage?
    @State private var selectedDuplicateID: String? = "group-a"
    @State private var selectedRecommendationID: String? = "group-a"
    @State private var selectedOperationID: String? = "op-valid"

    fileprivate init(
        sample: WorkflowProposalSample = .completed,
        selectedStage: WorkflowProposalStage = .duplicates
    ) {
        _sample = State(initialValue: sample)
        _selectedStage = State(initialValue: selectedStage)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedStage) {
                Section("Workflow") {
                    ForEach(WorkflowProposalStage.allCases) { stage in
                        NavigationLink(value: stage) {
                            StageRow(stage: stage, status: sample.status(for: stage))
                        }
                    }
                }
            }
            .navigationTitle("Consolidation")
            .safeAreaInset(edge: .bottom) {
                ProposalReadinessFooter(sample: sample)
            }
        } content: {
            switch selectedStage ?? .setup {
            case .setup:
                ScanRootsProposalView(sample: sample)
            case .scan:
                ScanRunProposalView(sample: sample)
            case .inventory:
                InventoryProposalView(documents: sample.documents)
            case .duplicates:
                DuplicateGroupProposalList(
                    groups: sample.duplicateGroups,
                    selectedID: $selectedDuplicateID
                )
            case .recommendations:
                RecommendationProposalList(
                    recommendations: sample.recommendations,
                    selectedID: $selectedRecommendationID
                )
            case .executionPlan:
                ExecutionOperationProposalList(
                    operations: sample.operations,
                    selectedID: $selectedOperationID
                )
            }
        } detail: {
            detailView
        }
        .frame(minWidth: 980, minHeight: 620)
    }

    @ViewBuilder private var detailView: some View {
        switch selectedStage ?? .setup {
        case .setup:
            ProposalPlaceholderDetail(title: "Scan roots", text: "Select roots in the content pane. Details remain fixed here instead of pushing the page down.")
        case .scan:
            ProposalPlaceholderDetail(title: sample.scanState, text: sample.scanMessage)
        case .inventory:
            ProposalPlaceholderDetail(title: "Inventory detail", text: "Selecting a document would show metadata, path, type, hash and duplicate status here.")
        case .duplicates:
            DuplicateGroupProposalDetail(group: sample.duplicateGroups.first { $0.id == selectedDuplicateID })
        case .recommendations:
            RecommendationProposalDetail(recommendation: sample.recommendations.first { $0.id == selectedRecommendationID })
        case .executionPlan:
            ExecutionOperationProposalDetail(operation: sample.operations.first { $0.id == selectedOperationID })
        }
    }
}

private enum WorkflowProposalStage: String, CaseIterable, Identifiable {
    case setup = "Scan Roots"
    case scan = "Scan"
    case inventory = "Inventory"
    case duplicates = "Duplicates"
    case recommendations = "Recommendations"
    case executionPlan = "Execution Plan"

    var id: Self { self }
    var icon: String {
        switch self {
        case .setup: "folder.badge.plus"
        case .scan: "waveform.path.ecg"
        case .inventory: "doc.text.magnifyingglass"
        case .duplicates: "doc.on.doc"
        case .recommendations: "checklist"
        case .executionPlan: "list.bullet.rectangle"
        }
    }
}

private struct StageRow: View {
    let stage: WorkflowProposalStage
    let status: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.rawValue)
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: stage.icon)
        }
    }
}

private struct ProposalReadinessFooter: View {
    let sample: WorkflowProposalSample

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(sample.readiness, systemImage: sample.invalidCount == 0 ? "checkmark.seal" : "exclamationmark.triangle")
                .font(.headline)
            Text("\(sample.acceptedCount) accepted · \(sample.rejectedCount) rejected · \(sample.invalidCount) invalid")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

private struct ScanRootsProposalView: View {
    let sample: WorkflowProposalSample

    var body: some View {
        ProposalListShell(title: "Scan roots", subtitle: "Define the folders that feed the workflow.") {
            ForEach(sample.roots, id: \.self) { root in
                Label(root, systemImage: "folder")
            }
        } footer: {
            Button("Add Root Folder", systemImage: "plus") {}
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct ScanRunProposalView: View {
    let sample: WorkflowProposalSample

    var body: some View {
        ProposalListShell(title: "Scan", subtitle: sample.scanMessage) {
            LabeledContent("Documents", value: sample.documents.count.formatted())
            LabeledContent("Duplicate groups", value: sample.duplicateGroups.count.formatted())
            LabeledContent("Recommendations", value: sample.recommendations.count.formatted())
            ProgressView(value: 1) { Text(sample.scanState) }
        } footer: {
            Button("Scan Selected Folders", systemImage: "play.fill") {}
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct InventoryProposalView: View {
    let documents: [ProposalDocument]

    var body: some View {
        ProposalListShell(title: "Inventory", subtitle: "A selectable document list keeps metadata out of the main workflow page.") {
            ForEach(documents) { document in
                HStack {
                    Image(systemName: document.isDuplicate ? "doc.on.doc" : "doc")
                    Text(document.name)
                    Spacer()
                    Text(document.kind).foregroundStyle(.secondary)
                    Text(document.size).foregroundStyle(.secondary)
                }
            }
        } footer: { EmptyView() }
    }
}

private struct DuplicateGroupProposalList: View {
    let groups: [ProposalDuplicateGroup]
    @Binding var selectedID: String?

    var body: some View {
        ProposalListShell(title: "Duplicate groups", subtitle: "Select a group; documents appear in the detail pane without expanding the list.") {
            ForEach(groups) { group in
                Button { selectedID = group.id } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(group.title)
                            Text(group.locations).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(group.documents.count) copies")
                    }
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(selectedID == group.id ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
        } footer: { EmptyView() }
    }
}

private struct RecommendationProposalList: View {
    let recommendations: [ProposalRecommendation]
    @Binding var selectedID: String?

    var body: some View {
        ProposalListShell(title: "Recommendations", subtitle: "Review duplicate files, choose what to keep or reject, then generate the recommendation.") {
            ForEach(recommendations) { recommendation in
                Button { selectedID = recommendation.id } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recommendation.title)
                            Text(recommendation.fileReviewSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(recommendation.decision).foregroundStyle(recommendation.decisionColor)
                    }
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(selectedID == recommendation.id ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
        } footer: { EmptyView() }
    }
}

private struct ExecutionOperationProposalList: View {
    let operations: [ProposalOperation]
    @Binding var selectedID: String?

    var body: some View {
        ProposalListShell(title: "Execution plan", subtitle: "Validation failures are scanned in the list and explained in detail on selection.") {
            ForEach(operations) { operation in
                Button { selectedID = operation.id } label: {
                    HStack {
                        Text(operation.title)
                        Spacer()
                        Text(operation.validation).foregroundStyle(operation.validationColor)
                    }
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(selectedID == operation.id ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }
        } footer: {
            Button("Refresh Validation", systemImage: "arrow.clockwise") {}
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct ProposalListShell<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle).foregroundStyle(.secondary)
            }
            List { content }
            HStack { footer; Spacer() }
        }
        .padding()
        .navigationTitle(title)
    }
}

private struct DuplicateGroupProposalDetail: View {
    let group: ProposalDuplicateGroup?

    var body: some View {
        ProposalDetailShell(title: group?.title ?? "No duplicate group selected") {
            if let group {
                LabeledContent("Hash", value: group.hash)
                LabeledContent("Locations", value: group.locations)
                Divider()
                ForEach(group.documents) { document in
                    Label(document.name, systemImage: document.preferred ? "checkmark.circle" : "doc")
                }
            }
        }
    }
}

private struct RecommendationProposalDetail: View {
    let recommendation: ProposalRecommendation?

    var body: some View {
        ProposalDetailShell(title: recommendation?.title ?? "No recommendation selected") {
            if let recommendation {
                Text(recommendation.rationale).foregroundStyle(.secondary)

                Section("Files in this duplicate group") {
                    ForEach(recommendation.files) { file in
                        HStack(spacing: 10) {
                            Image(systemName: file.roleIcon)
                                .foregroundStyle(file.roleColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                Text(file.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(file.role)
                                .foregroundStyle(file.roleColor)
                        }
                    }
                }

                Divider()

                HStack {
                    Button("Accept File", systemImage: "checkmark") {}
                    Button("Reject File", systemImage: "xmark") {}
                    Spacer()
                    Button("Generate Recommendation", systemImage: "sparkles") {}
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct ExecutionOperationProposalDetail: View {
    let operation: ProposalOperation?

    var body: some View {
        ProposalDetailShell(title: operation?.title ?? "No operation selected") {
            if let operation {
                LabeledContent("Source", value: operation.source)
                LabeledContent("Destination", value: operation.destination)
                LabeledContent("Validation", value: operation.validation)
                ForEach(operation.issues, id: \.self) { issue in
                    Label(issue, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
        }
    }
}

private struct ProposalPlaceholderDetail: View {
    let title: String
    let text: String

    var body: some View {
        ProposalDetailShell(title: title) { Text(text).foregroundStyle(.secondary) }
    }
}

private struct ProposalDetailShell<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.weight(.semibold))
            content
            Spacer()
        }
        .padding()
        .textSelection(.enabled)
    }
}

private struct WorkflowProposalSample {
    let roots: [String]
    let scanState: String
    let scanMessage: String
    let documents: [ProposalDocument]
    let duplicateGroups: [ProposalDuplicateGroup]
    let recommendations: [ProposalRecommendation]
    let operations: [ProposalOperation]

    var acceptedCount: Int { recommendations.filter { $0.decision == "Accepted" }.count }
    var rejectedCount: Int { recommendations.filter { $0.decision == "Rejected" }.count }
    var invalidCount: Int { operations.filter { $0.validation == "Invalid" }.count }
    var readiness: String { invalidCount == 0 ? "Ready for execution review" : "Not ready" }

    func status(for stage: WorkflowProposalStage) -> String {
        switch stage {
        case .setup: "\(roots.count) roots"
        case .scan: scanState
        case .inventory: "\(documents.count) documents"
        case .duplicates: "\(duplicateGroups.count) groups"
        case .recommendations: "\(acceptedCount) accepted"
        case .executionPlan: invalidCount == 0 ? "Valid" : "Validation failed"
        }
    }

    static let empty = WorkflowProposalSample(
        roots: [],
        scanState: "Not started",
        scanMessage: "Choose scan roots before starting the workflow.",
        documents: [],
        duplicateGroups: [],
        recommendations: [],
        operations: []
    )

    static let scanning = WorkflowProposalSample(
        roots: ["~/Development/DocumentConsolidate/tmp", "~/Documents/Archive"],
        scanState: "Scanning",
        scanMessage: "Hashing and analysing documents. Review stages remain available without moving the scan controls.",
        documents: [
            ProposalDocument("GroupA-original.txt", "Text", "1 KB", false, false),
            ProposalDocument("GroupA-copy.txt", "Text", "1 KB", false, false),
            ProposalDocument("unique.txt", "Text", "1 KB", false, false)
        ],
        duplicateGroups: [],
        recommendations: [],
        operations: []
    )

    static let completed = WorkflowProposalSample(
        roots: ["~/Development/DocumentConsolidate/tmp", "~/Documents/Archive", "~/Desktop/Review"],
        scanState: "Completed",
        scanMessage: "Scan complete. Review each stage from the sidebar.",
        documents: [
            ProposalDocument("GroupA-original.txt", "Text", "1 KB", true, true),
            ProposalDocument("GroupA-copy.txt", "Text", "1 KB", true, false),
            ProposalDocument("GroupB-original.txt", "Text", "1 KB", true, true),
            ProposalDocument("GroupB-copy.txt", "Text", "1 KB", true, false),
            ProposalDocument("unique.txt", "Text", "1 KB", false, false),
            ProposalDocument("non-unique.txt", "Text", "1 KB", false, false)
        ],
        duplicateGroups: [
            ProposalDuplicateGroup("group-a", "Group A", "a1b2c3d4e5f6", "tmp, Archive", [ProposalDocument("GroupA-original.txt", "Text", "1 KB", true, true), ProposalDocument("GroupA-copy.txt", "Text", "1 KB", true, false)]),
            ProposalDuplicateGroup("group-b", "Group B", "b1c2d3e4f5a6", "tmp, Desktop", [ProposalDocument("GroupB-original.txt", "Text", "1 KB", true, true), ProposalDocument("GroupB-copy.txt", "Text", "1 KB", true, false)])
        ],
        recommendations: [
            ProposalRecommendation(
                "group-a",
                "Group A",
                "Accepted",
                "Retain GroupA-original.txt and consolidate the duplicate copy.",
                [
                    ProposalRecommendationFile("GroupA-original.txt", "~/Development/DocumentConsolidate/tmp", "Keep"),
                    ProposalRecommendationFile("GroupA-copy.txt", "~/Documents/Archive", "Reject")
                ]
            ),
            ProposalRecommendation(
                "group-b",
                "Group B",
                "Rejected",
                "No retained-copy policy is approved for this group.",
                [
                    ProposalRecommendationFile("GroupB-original.txt", "~/Development/DocumentConsolidate/tmp", "Pending"),
                    ProposalRecommendationFile("GroupB-copy.txt", "~/Desktop/Review", "Pending")
                ]
            ),
            ProposalRecommendation(
                "group-c",
                "Group C",
                "Pending",
                "Requires review before an operation can be planned.",
                [
                    ProposalRecommendationFile("Quarterly Report.pdf", "~/Documents/Archive", "Pending"),
                    ProposalRecommendationFile("Quarterly Report copy.pdf", "~/Desktop/Review", "Pending")
                ]
            )
        ],
        operations: [
            ProposalOperation("op-valid", "Consolidate Group A copy", "Valid", "GroupA-copy.txt", "GroupA-original.txt", []),
            ProposalOperation("op-invalid", "Consolidate incomplete group", "Invalid", "Not specified", "Not specified", ["Accepted recommendation does not identify a retained copy.", "Source file could not be validated."])
        ]
    )
}

private struct ProposalDocument: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let size: String
    let isDuplicate: Bool
    let preferred: Bool

    init(_ name: String, _ kind: String, _ size: String, _ isDuplicate: Bool, _ preferred: Bool) {
        self.name = name
        self.kind = kind
        self.size = size
        self.isDuplicate = isDuplicate
        self.preferred = preferred
    }
}

private struct ProposalDuplicateGroup: Identifiable {
    let id: String
    let title: String
    let hash: String
    let locations: String
    let documents: [ProposalDocument]

    init(_ id: String, _ title: String, _ hash: String, _ locations: String, _ documents: [ProposalDocument]) {
        self.id = id
        self.title = title
        self.hash = hash
        self.locations = locations
        self.documents = documents
    }
}

private struct ProposalRecommendation: Identifiable {
    let id: String
    let title: String
    let decision: String
    let rationale: String
    let files: [ProposalRecommendationFile]
    var decisionColor: Color { decision == "Accepted" ? .green : decision == "Rejected" ? .red : .orange }
    var fileReviewSummary: String {
        let kept = files.filter { $0.role == "Keep" }.count
        let rejected = files.filter { $0.role == "Reject" }.count
        return "\(kept) keep · \(rejected) reject · \(files.count - kept - rejected) pending"
    }

    init(
        _ id: String,
        _ title: String,
        _ decision: String,
        _ rationale: String,
        _ files: [ProposalRecommendationFile]
    ) {
        self.id = id
        self.title = title
        self.decision = decision
        self.rationale = rationale
        self.files = files
    }
}

private struct ProposalRecommendationFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let role: String
    var roleIcon: String { role == "Keep" ? "checkmark.circle" : role == "Reject" ? "xmark.circle" : "questionmark.circle" }
    var roleColor: Color { role == "Keep" ? .green : role == "Reject" ? .red : .orange }

    init(_ name: String, _ path: String, _ role: String) {
        self.name = name
        self.path = path
        self.role = role
    }
}

private struct ProposalOperation: Identifiable {
    let id: String
    let title: String
    let validation: String
    let source: String
    let destination: String
    let issues: [String]
    var validationColor: Color { validation == "Valid" ? .green : .red }

    init(_ id: String, _ title: String, _ validation: String, _ source: String, _ destination: String, _ issues: [String]) {
        self.id = id
        self.title = title
        self.validation = validation
        self.source = source
        self.destination = destination
        self.issues = issues
    }
}

#Preview("Workflow proposal - empty setup") {
    WorkflowDesignProposalPreview(sample: .empty, selectedStage: .setup)
}

#Preview("Workflow proposal - active scan") {
    WorkflowDesignProposalPreview(sample: .scanning, selectedStage: .scan)
}

#Preview("Workflow proposal - recommendations") {
    WorkflowDesignProposalPreview(sample: .completed, selectedStage: .recommendations)
}

#Preview("Workflow proposal - completed review") {
    WorkflowDesignProposalPreview()
}
