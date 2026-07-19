// 2026-07-19 17:25 SGT

import SwiftUI

struct ExecutionPlanReviewView: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var selectedOperationID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageHeading("Archive Plan", subtitle: "Review redundant-copy archive operations and validation state.")
            planSummary
            HStack {
                Button(scanManager.executionPlan == nil ? "Generate and Validate Archive Plan" : "Refresh Validation", systemImage: "arrow.clockwise") {
                    Task { await scanManager.generateExecutionPlan() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(scanManager.currentSession == nil || scanManager.inventory.isGeneratingExecutionPlan)
                if scanManager.inventory.isGeneratingExecutionPlan {
                    ProgressView("Updating")
                }
            }
            List(scanManager.executionPlan?.operations ?? [], selection: $selectedOperationID) { operation in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(operation.type.rawValue)
                        Text(operation.sourceDocument?.filename ?? "Source not specified")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(operation.validationStatus.rawValue)
                        .foregroundStyle(validationColor(operation.validationStatus))
                }
                .tag(operation.id)
            }
        }
        .padding()
        .navigationTitle("Archive Plan")
    }

    private var planSummary: some View {
        HStack(spacing: 16) {
            LabeledContent("Planned", value: (scanManager.executionPlan?.operations.count ?? 0).formatted())
            LabeledContent("Valid", value: (scanManager.executionPlan?.validOperationCount ?? 0).formatted())
            LabeledContent("Invalid", value: (scanManager.executionPlan?.invalidOperationCount ?? 0).formatted())
            LabeledContent("Pending", value: (scanManager.executionPlan?.pendingOperationCount ?? 0).formatted())
        }
    }

    private func validationColor(_ status: OperationValidationStatus) -> Color {
        switch status {
        case .pending: .orange
        case .valid: .green
        case .invalid: .red
        }
    }
}

struct ExecutionOperationDetailView: View {
    let operation: PlannedOperation?

    var body: some View {
        DetailShell(title: operation?.type.rawValue ?? "No operation selected") {
            if let operation {
                DetailField("Operation identifier", value: operation.id, monospaced: true)
                DetailField("Duplicate group", value: operation.recommendationID, monospaced: true)
                DetailField("Redundant source", value: operation.sourceDocument?.url.path ?? "Not specified")
                DetailField("Definitive copy", value: operation.definitiveDocument.url.path)
                DetailField("Archive destination", value: operation.destination?.path ?? "Not yet defined")
                LabeledContent("Archive execution", value: operation.executionStatus.rawValue)
                LabeledContent("Validation", value: operation.validationStatus.rawValue)
                Text(operation.reason)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                if !operation.validationIssues.isEmpty {
                    Divider()
                    Text("Validation issues").font(.headline)
                    ForEach(operation.validationIssues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("No filesystem changes have been made.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
