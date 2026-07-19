// 2026-07-19 17:25 SGT
//
//  ContentView.swift
//  DocumentConsolidate
//
//  Created by Hei Long Xia on 18/7/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(ScanManager.self) private var scanManager
    @State private var selectedStage: WorkflowStage? = .scanRoots
    @State private var selectedDocumentID: UUID?
    @State private var selectedDuplicateGroupID: String?
    @State private var selectedRecommendationID: String?
    @State private var selectedOperationID: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedStage) {
                Section("Workflow") {
                    ForEach(WorkflowStage.allCases) { stage in
                        NavigationLink(value: stage) {
                            WorkflowStageRow(stage: stage, status: status(for: stage))
                        }
                    }
                }
            }
            .navigationTitle("Consolidation")
            .safeAreaInset(edge: .bottom) { WorkflowStatusView() }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } content: {
            contentView
                .navigationSplitViewColumnWidth(min: 340, ideal: 420, max: 600)
        } detail: {
            detailView
                .navigationSplitViewColumnWidth(min: 360, ideal: 480)
        }
        .frame(minWidth: 980, minHeight: 620)
    }

    @ViewBuilder private var contentView: some View {
        switch selectedStage ?? .scanRoots {
        case .scanRoots:
            ScanRootsStageView()
        case .scan:
            ScanStageView()
        case .inventory:
            DocumentListView(documents: scanManager.documents, selectedDocumentID: $selectedDocumentID)
        case .duplicates:
            DuplicateGroupsView(groups: duplicateGroups, selectedGroupID: $selectedDuplicateGroupID)
        case .recommendations:
            RecommendationReviewView(selectedRecommendationID: $selectedRecommendationID)
        case .executionPlan:
            ExecutionPlanReviewView(selectedOperationID: $selectedOperationID)
        }
    }

    @ViewBuilder private var detailView: some View {
        switch selectedStage ?? .scanRoots {
        case .scanRoots:
            WorkflowPlaceholderDetail(
                title: "Scan folders",
                message: "Add or remove source folders in the content pane. Scanning never modifies these folders."
            )
        case .scan:
            WorkflowPlaceholderDetail(
                title: "Analysis pipeline",
                message: "Filesystem enumeration, document analysis, hashing, exact-duplicate detection, archival approval, and archive planning remain separate phases."
            )
        case .inventory:
            DocumentDetailView(document: scanManager.documents.first { $0.id == selectedDocumentID })
        case .duplicates:
            DuplicateGroupDetailView(group: duplicateGroups.first { $0.id == selectedDuplicateGroupID })
        case .recommendations:
            RecommendationDetailView(
                recommendation: scanManager.recommendations.first { $0.id == selectedRecommendationID },
                reviewArchivePlan: { selectedStage = .executionPlan }
            )
        case .executionPlan:
            ExecutionOperationDetailView(
                operation: scanManager.executionPlan?.operations.first { $0.id == selectedOperationID }
            )
        }
    }

    private var duplicateGroups: [DuplicateGroupSummary] {
        DuplicateGroupsView.groups(from: scanManager.documents)
    }

    private func status(for stage: WorkflowStage) -> String {
        switch stage {
        case .scanRoots:
            "\(scanManager.selectedRootFolders.count) roots"
        case .scan:
            scanManager.isScanning ? "Running" : (scanManager.currentSession == nil ? "Not started" : "Complete")
        case .inventory:
            "\(scanManager.documents.count) documents"
        case .duplicates:
            "\(duplicateGroups.count) groups"
        case .recommendations:
            "\(scanManager.recommendations.filter { $0.decision == .approved }.count) approved"
        case .executionPlan:
            executionPlanStatus
        }
    }

    private var executionPlanStatus: String {
        guard let plan = scanManager.executionPlan else { return "Not generated" }
        if scanManager.inventory.isGeneratingExecutionPlan { return "Validating" }
        return plan.invalidOperationCount == 0 ? "Valid" : "\(plan.invalidOperationCount) invalid"
    }
}

private struct WorkflowPlaceholderDetail: View {
    let title: String
    let message: String

    var body: some View {
        DetailShell(title: title) {
            Text(message).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let inventory = Inventory()
    ContentView()
        .environment(ScanManager(inventory: inventory))
}
