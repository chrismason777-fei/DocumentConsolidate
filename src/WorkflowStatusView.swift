// 2026-07-19 17:25 SGT

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
        guard let plan = scanManager.executionPlan else { return "Archive plan not generated" }
        if scanManager.inventory.isGeneratingExecutionPlan { return "Validating archive plan" }
        return plan.isReady ? "Ready" : "Not ready"
    }

    private var readinessIcon: String {
        scanManager.executionPlan?.isReady == true ? "checkmark.seal" : "exclamationmark.triangle"
    }

    private var readinessColor: Color {
        scanManager.executionPlan?.isReady == true ? .green : .orange
    }

    private var statusSummary: String {
        let approved = scanManager.recommendations.filter { $0.decision == .approved }.count
        let rejected = scanManager.recommendations.filter { $0.decision == .rejected }.count
        let postponed = scanManager.recommendations.filter { $0.decision == .postponed }.count
        let invalid = scanManager.executionPlan?.invalidOperationCount ?? 0
        return "\(approved) approved · \(rejected) rejected · \(postponed) postponed · \(invalid) invalid"
    }
}
