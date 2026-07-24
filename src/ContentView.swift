// 2026-07-24 16:55 SGT
//
//  ContentView.swift
//  DocumentConsolidate
//
//  Created by Hei Long Xia on 18/7/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(ScanManager.self) private var scanManager
    @State private var selectedStage: WorkflowStage? = .prepareScan
    @State private var selectedRecommendationID: String?
    @State private var selectedOperationID: String?
    @State private var isResetAllConfirmationPresented = false

    var body: some View {
        NavigationSplitView {
            List {
                Section("Workflow") {
                    ForEach(WorkflowStage.allCases) { stage in
                        Button { selectedStage = stage } label: {
                            WorkflowStageRow(stage: stage, status: status(for: stage))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    selectedStage == stage ? Color.accentColor : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Document Consolidate")
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
        .toolbar {
            Menu {
                Button("Reset All Decisions…", systemImage: "arrow.counterclockwise") {
                    isResetAllConfirmationPresented = true
                }
                .disabled(!hasRecommendationReviewState || scanManager.inventory.isGeneratingExecutionPlan)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .disabled(selectedStage != .recommendations)
        }
    }

    @ViewBuilder private var contentView: some View {
        switch selectedStage ?? .prepareScan {
        case .prepareScan:
            PrepareScanStageView()
        case .recommendations:
            RecommendationReviewView(
                selectedRecommendationID: $selectedRecommendationID,
                isResetAllConfirmationPresented: $isResetAllConfirmationPresented,
                reviewArchivePlan: { selectedStage = .executionPlan }
            )
        case .executionPlan:
            ExecutionPlanReviewView(selectedOperationID: $selectedOperationID)
        }
    }

    @ViewBuilder private var detailView: some View {
        switch selectedStage ?? .prepareScan {
        case .prepareScan:
            PrepareScanStatusView(onScanComplete: { selectedStage = .recommendations })
        case .recommendations:
            RecommendationDetailView(
                recommendation: scanManager.recommendations.first { $0.id == selectedRecommendationID }
            )
        case .executionPlan:
            ExecutionOperationDetailView(
                operation: scanManager.executionPlan?.operations.first { $0.id == selectedOperationID },
                planIsReady: scanManager.executionPlan?.isReady == true
            )
        }
    }

    private func status(for stage: WorkflowStage) -> String {
        switch stage {
        case .prepareScan:
            prepareScanStatus
        case .recommendations:
            recommendationStatus
        case .executionPlan:
            executionPlanStatus
        }
    }

    private var prepareScanStatus: String {
        if scanManager.isScanning { return "Running" }
        if scanManager.currentSession != nil { return "Complete" }
        return "\(scanManager.selectedRootFolders.count) roots"
    }

    private var executionPlanStatus: String {
        guard let plan = scanManager.executionPlan else { return "Not generated" }
        if scanManager.inventory.isGeneratingExecutionPlan { return "Validating" }
        if plan.isReady { return "Execution ready" }
        if plan.invalidOperationCount > 0 { return "\(plan.invalidOperationCount) invalid" }
        if plan.operations.contains(where: { $0.destination == nil }) { return "Destination required" }
        return "Not ready"
    }

    private var recommendationStatus: String {
        let attention = scanManager.recommendations.filter { $0.status == .needsSelection }.count
        if attention > 0 { return "\(attention) need selection" }
        let ready = scanManager.recommendations.filter { $0.isReadyForApproval && $0.decision == .pending }.count
        if ready > 0 { return "\(ready) ready to approve" }
        return "\(scanManager.recommendations.filter { $0.decision == .approved }.count) approved"
    }

    private var hasRecommendationReviewState: Bool {
        scanManager.recommendations.contains { scanManager.recommendationDiffersFromBaseline(id: $0.id) }
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
