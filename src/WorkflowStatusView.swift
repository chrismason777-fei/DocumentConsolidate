// 2026-07-20 14:22 SGT

import SwiftUI

struct WorkflowStatusView: View {
    @Environment(ScanManager.self) private var scanManager

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label {
                LabeledContent("Execution Ready", value: readiness)
            } icon: {
                Image(systemName: readinessIcon)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(readinessColor)
            Text(statusSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var readiness: String {
        guard let plan = scanManager.executionPlan else { return "No" }
        if scanManager.inventory.isGeneratingExecutionPlan { return "Validating" }
        return plan.isReady ? "Yes" : "No"
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
        return "\(approved) approved · \(rejected) rejected · \(postponed) postponed"
    }
}
