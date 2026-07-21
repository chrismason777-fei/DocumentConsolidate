// 2026-07-21 11:02 SGT

import SwiftUI
import UniformTypeIdentifiers

struct PrepareScanStageView: View {
    @Environment(ScanManager.self) private var scanManager
    @State private var isFolderPickerPresented = false
    @State private var pickerError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageHeading("Prepare Scan", subtitle: "Choose the folders to include in the scan.")
            Text(scanManager.selectedRootFolders.count, format: .number)
                .font(.title3.weight(.semibold))
                .contentTransition(.numericText())
                .accessibilityLabel("\(scanManager.selectedRootFolders.count) configured folders")
            Text(scanManager.selectedRootFolders.count == 1 ? "configured folder" : "configured folders")
                .font(.caption)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack {
                    addFolderButton
                    clearFoldersButton
                }
                VStack(alignment: .leading) {
                    addFolderButton.frame(maxWidth: .infinity)
                    clearFoldersButton.frame(maxWidth: .infinity)
                }
            }
            List(scanManager.selectedRootFolders, id: \.self) { folder in
                HStack {
                    Label {
                        Text(folder.path(percentEncoded: false))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: "folder")
                    }
                    Spacer()
                    Button("Remove") { scanManager.removeRootFolder(folder) }
                }
            }
            if let pickerError { Text(pickerError).foregroundStyle(.red) }
        }
        .padding()
        .navigationTitle("Prepare Scan")
        .fileImporter(isPresented: $isFolderPickerPresented, allowedContentTypes: [.folder]) { result in
            do {
                scanManager.addRootFolder(try result.get())
                pickerError = nil
            } catch {
                pickerError = error.localizedDescription
            }
        }
    }

    private var addFolderButton: some View {
        Button("Add Root Folder", systemImage: "plus") { isFolderPickerPresented = true }
            .buttonStyle(.bordered)
    }

    private var clearFoldersButton: some View {
        Button("Clear Root Folders") { scanManager.clearRootFolders() }
            .disabled(scanManager.selectedRootFolders.isEmpty)
    }
}

struct PrepareScanStatusView: View {
    @Environment(ScanManager.self) private var scanManager
    @State private var scanError: String?

    let onScanComplete: () -> Void

    var body: some View {
        DetailShell(title: title) {
            statusContent
        }
    }

    private var title: String {
        if scanManager.isScanning { return "Scanning" }
        if scanError != nil { return "Scan Failed" }
        if scanManager.currentSession != nil { return "Previous Scan" }
        return "Prepare to Scan"
    }

    @ViewBuilder private var statusContent: some View {
        if scanManager.isScanning {
            Text("Document Consolidate is analysing the configured folders.")
                .foregroundStyle(.secondary)
            progress
            actionLayout(showStop: true, showReset: false)
        } else if let scanError {
            Label(scanError, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            actionLayout(showStop: false, showReset: scanManager.currentSession != nil)
        } else if let session = scanManager.currentSession {
            Text("The most recently completed scan is shown below.")
                .foregroundStyle(.secondary)
            ScanSummaryView(session: session)
            actionLayout(showStop: false, showReset: true)
        } else if scanManager.selectedRootFolders.isEmpty {
            Text("Add at least one folder in the centre pane to begin.")
                .foregroundStyle(.secondary)
            scanButton
        } else {
            LabeledContent("Configured folders", value: scanManager.selectedRootFolders.count.formatted())
                .font(.headline)
            Label("Scanning analyses files without modifying them.", systemImage: "checkmark.shield")
                .foregroundStyle(.secondary)
            scanButton
        }
    }

    private func actionLayout(showStop: Bool, showReset: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                scanButton
                if showStop { stopButton }
                if showReset { resetButton }
            }
            VStack(alignment: .leading) {
                scanButton.frame(maxWidth: .infinity)
                if showStop { stopButton }
                if showReset { resetButton }
            }
        }
    }

    @ViewBuilder private var progress: some View {
        if scanManager.isHashing {
            ProgressView(value: Double(scanManager.hashCompletedCount), total: Double(max(scanManager.hashTotalCount, 1))) {
                HStack {
                    Text("Generating document identities")
                    Spacer()
                    Text(
                        Double(scanManager.hashCompletedCount) / Double(max(scanManager.hashTotalCount, 1)),
                        format: .percent.precision(.fractionLength(0))
                    )
                }
            }
        } else if scanManager.isAnalysing {
            ProgressView(value: Double(scanManager.analysisCompletedCount), total: Double(max(scanManager.analysisTotalCount, 1))) {
                HStack {
                    Text("Analysing documents")
                    Spacer()
                    Text(
                        Double(scanManager.analysisCompletedCount) / Double(max(scanManager.analysisTotalCount, 1)),
                        format: .percent.precision(.fractionLength(0))
                    )
                }
            }
        } else if scanManager.isScanning {
            ProgressView("Enumerating documents")
        }
    }

    private var scanButton: some View {
        Button("Scan Selected Folders", systemImage: "play.fill") { Task { await runScan() } }
            .buttonStyle(.borderedProminent)
            .disabled(scanManager.selectedRootFolders.isEmpty || scanManager.isScanning)
    }

    private var stopButton: some View {
        Button("Stop Scan") { scanManager.stopScan() }
            .disabled(!scanManager.isScanning)
    }

    private var resetButton: some View {
        Button("Reset Scan Session") { Task { await scanManager.resetSession() } }
            .disabled(scanManager.currentSession == nil)
    }

    private func runScan() async {
        do {
            try await scanManager.scan()
            scanError = nil
            onScanComplete()
        } catch {
            scanError = error.localizedDescription
        }
    }
}

struct StageHeading: View {
    let title: String
    let subtitle: String

    init(_ title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary)
        }
    }
}
