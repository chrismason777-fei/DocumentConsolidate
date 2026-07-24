// 2026-07-24 16:10 SGT

import SwiftUI

struct ExecutionControlsView: View {
    @Environment(ScanManager.self) private var scanManager
    @State private var isConfirmationPresented = false
    @State private var isSummaryPresented = false
    @State private var summary: ExecutionSummary?
    @State private var globalFailureMessage: String?

    var body: some View {
        Group {
            if scanManager.inventory.isExecuting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Relocating approved documents…")
                }
                .font(.callout.weight(.semibold))
            } else if summary != nil {
                Button("View Execution Summary", systemImage: "checkmark.circle.fill") {
                    isSummaryPresented = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .fixedSize(horizontal: true, vertical: false)
            } else if scanManager.executionPlan?.isReady == true {
                Button("Execute Archive Plan", systemImage: "archivebox.fill") {
                    isConfirmationPresented = true
                }
                .buttonStyle(.borderedProminent)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .confirmationDialog(
            "Execute Archive Plan?",
            isPresented: $isConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Relocate Approved Documents") { execute() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Approved redundant documents will be copied and verified in the archive before their originals are removed. Definitive documents remain unchanged.")
        }
        .alert(
            "Execution Could Not Begin",
            isPresented: failurePresentation,
            actions: { Button("OK") { globalFailureMessage = nil } },
            message: { Text(globalFailureMessage ?? "The Archive Plan could not be executed.") }
        )
        .sheet(isPresented: $isSummaryPresented) {
            if let summary {
                ExecutionSummaryView(summary: summary)
            }
        }
    }

    private var failurePresentation: Binding<Bool> {
        Binding(
            get: { globalFailureMessage != nil },
            set: { if !$0 { globalFailureMessage = nil } }
        )
    }

    private func execute() {
        Task {
            switch await scanManager.executePublishedPlan() {
            case .success(let executionSummary):
                summary = executionSummary
                isSummaryPresented = true
            case .failure(let error):
                globalFailureMessage = message(for: error)
            }
        }
    }

    private func message(for error: ExecutionLifecycleError) -> String {
        switch error {
        case .noPublishedPlan:
            "The published Archive Plan is no longer ready. Refresh validation before trying again."
        case .executionInProgress:
            "An archive execution is already in progress."
        case .destinationAccess(let accessError):
            "The archive destination could not be accessed (\(String(describing: accessError)))."
        case .destinationAccessFailed:
            "The archive destination could not be accessed."
        case .globalPreflightFailed(let message):
            message
        }
    }
}

private struct ExecutionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let summary: ExecutionSummary

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                summaryHeader
                if summary.results.isEmpty {
                    ContentUnavailableView("No Operations Executed", systemImage: "archivebox")
                } else {
                    List(summary.results) { result in
                        resultRow(result)
                    }
                    .listStyle(.inset)
                }
            }
            .padding(20)
            .frame(minWidth: 620, minHeight: 440)
            .navigationTitle("Execution Complete")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 12) {
            Label("\(summary.successfulOperationCount) succeeded", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Label("\(summary.failedOperationCount) failed", systemImage: "xmark.circle.fill")
                .foregroundStyle(summary.failedOperationCount == 0 ? Color.secondary : Color.red)
            Spacer()
            Text("Execution \(summary.executionID.uuidString.prefix(8))")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .font(.headline)
    }

    private func resultRow(_ result: OperationExecutionResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.outcome == .succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.outcome == .succeeded ? .green : .red)
            VStack(alignment: .leading, spacing: 5) {
                Text(result.sourceURL.lastPathComponent).font(.body.weight(.semibold))
                Text(result.outcome.rawValue).font(.caption.weight(.semibold))
                Text(result.message).font(.caption).foregroundStyle(.secondary)
                if let destination = result.destinationURL {
                    Text(destination.path(percentEncoded: false))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
