// 2026-07-19 14:20 SGT

import SwiftUI

struct WorkflowStatusView: View {
    @Environment(ScanManager.self) private var scanManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(readiness, systemImage: readinessIcon)
                .font(.headline)
                .foregroundStyle(readinessColor)
            Text(statusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("No filesystem changes have been made.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var readiness: String {
        guard let plan = scanManager.executionPlan else { return "Plan not generated" }
        if scanManager.inventory.isGeneratingExecutionPlan { return "Validating plan" }
        return plan.isReady ? "Ready" : "Not ready"
    }

    private var readinessIcon: String {
        scanManager.executionPlan?.isReady == true ? "checkmark.seal" : "exclamationmark.triangle"
    }

    private var readinessColor: Color {
        scanManager.executionPlan?.isReady == true ? .green : .orange
    }

    private var statusSummary: String {
        let accepted = scanManager.recommendations.filter { $0.decision == .accepted }.count
        let rejected = scanManager.recommendations.filter { $0.decision == .rejected }.count
        let invalid = scanManager.executionPlan?.invalidOperationCount ?? 0
        return "\(accepted) accepted · \(rejected) rejected · \(invalid) invalid"
    }
}

