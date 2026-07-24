// 2026-07-24 16:10 SGT

import SwiftUI

struct ExecutionPlanReviewView: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var selectedOperationID: String?
    @State private var destinationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WorkflowStageBanner(
                title: "Archive Plan",
                subtitle: "Review what stays, what would be archived, and what prevents safe execution."
            )
            .padding(20)
            metrics.padding(.horizontal, 20).padding(.bottom, 18)
            ArchiveDestinationSection(errorMessage: $destinationError)
                .padding(.horizontal, 20).padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PLANNED ARCHIVAL").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(readinessExplanation).font(.caption).foregroundStyle(readinessColor)
                }
                HStack {
                    Spacer()
                    Button(scanManager.executionPlan == nil ? "Prepare Archive Plan" : "Refresh Validation", systemImage: "arrow.clockwise") {
                        refreshPlan()
                    }
                    .buttonStyle(.borderedProminent)
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(scanManager.currentSession == nil || scanManager.inventory.isGeneratingExecutionPlan)
                    ExecutionControlsView()
                    if scanManager.inventory.isGeneratingExecutionPlan { ProgressView().controlSize(.small) }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 10)
            if scanManager.executionPlan?.operations.isEmpty != false {
                ContentUnavailableView(
                    "Archive Plan Is Empty",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Approved duplicate groups will add their redundant copies here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(scanManager.executionPlan?.operations ?? [], selection: $selectedOperationID) { operation in
                    operationRow(operation).tag(operation.id)
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle("Archive Plan")
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            WorkflowMetricCard(value: (scanManager.executionPlan?.operations.count ?? 0).formatted(), label: "Planned archives", color: .indigo)
            WorkflowMetricCard(value: (scanManager.executionPlan?.validOperationCount ?? 0).formatted(), label: "Validated", color: .green)
            WorkflowMetricCard(value: readiness, label: "Execution ready", color: readinessColor)
        }
    }

    private func refreshPlan() {
        guard scanManager.inventory.archiveDestination != nil else {
            destinationError = "Choose an Archive Destination before preparing or refreshing the plan."
            return
        }
        Task {
            destinationError = ArchiveDestinationPresentation.message(
                for: await scanManager.generateExecutionPlan()
            )
        }
    }

    private func operationRow(_ operation: PlannedOperation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "archivebox.fill").font(.title3).foregroundStyle(operationColor(operation)).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                Text(operation.sourceDocument?.filename ?? "Source not specified").font(.body.weight(.semibold))
                Text(operation.reason).font(.caption).foregroundStyle(.secondary)
                Text(operation.sourceDocument?.url.path(percentEncoded: false) ?? "Source path not specified")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            WorkflowStatusBadge(text: operationStatus(operation), color: operationColor(operation))
        }
        .padding(.vertical, 7)
    }

    private var readiness: String {
        if scanManager.inventory.isGeneratingExecutionPlan { return "Validating" }
        return scanManager.executionPlan?.isReady == true ? "Yes" : "No"
    }
    private var readinessColor: Color { scanManager.executionPlan?.isReady == true ? .green : .orange }
    private var readinessExplanation: String {
        guard let plan = scanManager.executionPlan else { return "Prepare the plan after approving duplicate groups." }
        if scanManager.inventory.isGeneratingExecutionPlan { return "Validation is in progress." }
        if plan.isReady { return "Every operation is validated and has a destination." }
        if plan.operations.contains(where: { $0.destination == nil }) { return "Archive destination is not defined; execution is unavailable." }
        if plan.invalidOperationCount > 0 { return "Resolve invalid operations before execution." }
        return "Complete validation before execution."
    }
    private func operationStatus(_ operation: PlannedOperation) -> String {
        if operation.validationStatus == .invalid { return "Invalid" }
        if operation.destination == nil { return "Destination not defined" }
        return operation.validationStatus.rawValue
    }
    private func operationColor(_ operation: PlannedOperation) -> Color {
        if operation.validationStatus == .invalid { return .red }
        if operation.destination == nil || operation.validationStatus == .pending { return .orange }
        return .green
    }
}

struct ExecutionOperationDetailView: View {
    let operation: PlannedOperation?
    let planIsReady: Bool

    var body: some View {
        ScrollView {
            if let operation {
                VStack(alignment: .leading, spacing: 22) {
                    header(operation)
                    operationStatus(operation)
                    Text("PLANNED OUTCOME").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    WorkflowOutcomeCard(outcome: "KEEP", document: operation.definitiveDocument, color: .indigo, isSelected: true)
                    if let source = operation.sourceDocument {
                        WorkflowOutcomeCard(outcome: "ARCHIVE", document: source, color: .orange, isSelected: true)
                    } else {
                        Label("Archive source is not specified.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                    operationDetails(operation)
                    validationEvidence(operation)
                    Text("Archive Plan is for review only. No filesystem changes have been made.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(28)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView("No archive operation selected", systemImage: "archivebox")
                    .frame(maxWidth: .infinity, minHeight: 420)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ operation: PlannedOperation) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(operation.sourceDocument.map { "Archive \($0.filename)" } ?? operation.type.rawValue).font(.title.weight(.bold))
                Text("Approved for the Archive Plan; review validation before execution.").foregroundStyle(.secondary)
            }
            Spacer()
            WorkflowStatusBadge(text: statusBadge(operation), color: statusColor(operation))
        }
    }

    private func operationStatus(_ operation: PlannedOperation) -> some View {
        let presentation = statusPresentation(operation)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: presentation.icon).font(.title3).foregroundStyle(presentation.color).frame(width: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text("OPERATION STATUS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                Text(presentation.title).font(.headline).foregroundStyle(presentation.color)
                Text(presentation.message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let guidance = presentation.guidance {
                    Text(guidance).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(presentation.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func operationDetails(_ operation: PlannedOperation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OPERATION DETAILS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
            labelledValue("Reason", operation.reason)
            labelledValue("Archive destination", operation.destination?.path(percentEncoded: false) ?? "Not defined", color: operation.destination == nil ? .orange : .primary)
        }
        .padding(16).background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func validationEvidence(_ operation: PlannedOperation) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("VALIDATION EVIDENCE").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
            evidenceRow("Source file exists", operation: operation, issueTerms: ["source file no longer exists", "source file could not"])
            evidenceRow("Duplicate contents verified", operation: operation, issueTerms: ["hash", "analysed document"])
            WorkflowValidationRow(label: "Destination defined", value: operation.destination == nil ? "Unresolved" : "Defined", color: operation.destination == nil ? .orange : .green, icon: operation.destination == nil ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            Divider()
            WorkflowValidationRow(label: "Operation validation", value: operation.validationStatus.rawValue, color: validationColor(operation.validationStatus), icon: operation.validationStatus == .valid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            ForEach(operation.validationIssues, id: \.self) { issue in
                Label(issue, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16).background(validationSurface(operation), in: RoundedRectangle(cornerRadius: 12))
    }

    private func evidenceRow(_ label: String, operation: PlannedOperation, issueTerms: [String]) -> some View {
        let failed = operation.validationIssues.contains { issue in issueTerms.contains { issue.localizedCaseInsensitiveContains($0) } }
        let verified = operation.validationStatus == .valid && !failed
        return WorkflowValidationRow(label: label, value: failed ? "Failed" : (verified ? "Verified" : "Needs review"), color: failed ? .red : (verified ? .green : .orange), icon: failed ? "xmark.circle.fill" : (verified ? "checkmark.circle.fill" : "exclamationmark.circle.fill"))
    }

    private func labelledValue(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.body.weight(.medium)).foregroundStyle(color).textSelection(.enabled)
        }
    }
    private func validationColor(_ status: OperationValidationStatus) -> Color {
        switch status { case .pending: .orange; case .valid: .green; case .invalid: .red }
    }
    private func validationSurface(_ operation: PlannedOperation) -> Color {
        operation.validationStatus == .invalid ? .red.opacity(0.07) : (planIsReady ? .green.opacity(0.07) : .orange.opacity(0.07))
    }
    private func statusBadge(_ operation: PlannedOperation) -> String {
        switch operation.validationStatus {
        case .pending: "Validating"
        case .invalid: "Invalid"
        case .valid: planIsReady ? "Ready" : "Blocked"
        }
    }
    private func statusColor(_ operation: PlannedOperation) -> Color {
        operation.validationStatus == .invalid ? .red : (planIsReady ? .green : .orange)
    }
    private func statusPresentation(_ operation: PlannedOperation) -> (title: String, message: String, guidance: String?, color: Color, icon: String) {
        switch operation.validationStatus {
        case .pending:
            return ("Validation is not complete.", "The selected operation has not finished validation.", "Refresh validation.", .orange, "clock.fill")
        case .invalid:
            return ("Validation failed.", "The selected operation cannot be executed.", "Resolve the issues below before execution.", .red, "xmark.circle.fill")
        case .valid where operation.destination == nil:
            return ("Validation passed. Cannot execute yet.", "Archive destination has not been configured.", "Configure the archive destination before execution.", .orange, "exclamationmark.circle.fill")
        case .valid where planIsReady:
            return ("Validation passed.", "The overall Archive Plan is ready to execute.", nil, .green, "checkmark.circle.fill")
        case .valid:
            return ("Validation passed for this operation.", "The overall Archive Plan is blocked by another operation.", "Review the remaining planned archives.", .orange, "exclamationmark.circle.fill")
        }
    }
}
