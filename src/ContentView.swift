// 2026-07-18 23:05 SGT
//
//  ContentView.swift
//  DocumentConsolidate
//
//  Created by Hei Long Xia on 18/7/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(ScanManager.self) private var scanManager
    @State private var isFolderPickerPresented = false
    @State private var scanError: String?
    @State private var expandedDuplicateGroups: Set<String> = []

    var body: some View {
        VStack(spacing: 12) {
            Text("Document Consolidator")
                .font(.title)

            if let session = scanManager.currentSession {
                LabeledContent("Session identifier", value: session.id.uuidString)
                LabeledContent("Created") {
                    Text(session.createdAt, format: .dateTime)
                }
                LabeledContent("Scanned roots", value: session.sourceFolders.count.formatted())
                LabeledContent("Unique documents", value: session.uniqueDocumentCount.formatted())
                LabeledContent("Duplicate documents", value: session.duplicateDocumentCount.formatted())
                LabeledContent("Duplicate groups", value: session.duplicateGroupCount.formatted())
                LabeledContent("Duplicate analysis", value: session.duplicateAnalysisStatus.rawValue)
            } else {
                Text("No scan session")
                    .foregroundStyle(.secondary)
            }

            GroupBox(rootFolderSectionTitle) {
                ForEach(scanManager.selectedRootFolders, id: \.self) { folder in
                    HStack {
                        Text(folder.path(percentEncoded: false))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Remove") {
                            scanManager.removeRootFolder(folder)
                        }
                    }
                }
            }

            LabeledContent("Documents", value: scanManager.documents.count.formatted())

            if scanManager.isHashing {
                ProgressView(
                    value: Double(scanManager.hashCompletedCount),
                    total: Double(max(scanManager.hashTotalCount, 1))
                ) {
                    HStack {
                        Text("Generating document identities")
                        Spacer()
                        Text(
                            Double(scanManager.hashCompletedCount)
                                / Double(max(scanManager.hashTotalCount, 1)),
                            format: .percent.precision(.fractionLength(0))
                        )
                    }
                }
            } else if scanManager.isAnalysing {
                ProgressView(
                    value: Double(scanManager.analysisCompletedCount),
                    total: Double(max(scanManager.analysisTotalCount, 1))
                ) {
                    HStack {
                        Text("Analysing documents")
                        Spacer()
                        Text(
                            Double(scanManager.analysisCompletedCount)
                                / Double(max(scanManager.analysisTotalCount, 1)),
                            format: .percent.precision(.fractionLength(0))
                        )
                    }
                }
            } else if scanManager.isScanning {
                ProgressView("Enumerating documents")
            }

            HStack {
                Button("Add Root Folder") {
                    isFolderPickerPresented = true
                }

                Button("Clear Root Folders") {
                    scanManager.clearRootFolders()
                }
                .disabled(scanManager.selectedRootFolders.isEmpty)

                Button("Scan Selected Folders") {
                    Task {
                        do {
                            try await scanManager.scan()
                            scanError = nil
                        } catch {
                            scanError = error.localizedDescription
                        }
                    }
                }
                .disabled(scanManager.selectedRootFolders.isEmpty || scanManager.isScanning)

                Button("Stop Scan") {
                    scanManager.stopScan()
                }
                .disabled(!scanManager.isScanning)

                Button("Reset Scan Session") {
                    scanManager.resetSession()
                }
                .disabled(scanManager.currentSession == nil)
            }

            if let scanError {
                Text(scanError)
                    .foregroundStyle(.red)
            }

            List(scanManager.documents) { document in
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.filename)
                    HStack {
                        Text(document.displayDocumentType ?? "Awaiting analysis")
                        Text(document.category?.rawValue ?? "Uncategorised")
                        Text(document.fileSize, format: .byteCount(style: .file))
                        Text(document.isSupported.map { $0 ? "Supported" : "Unsupported" } ?? "Support pending")
                        Text(document.analysisStatus.rawValue)
                        Text("Hash: \(document.hashStatus.rawValue)")
                        Text("Duplicate: \(document.duplicateStatus.rawValue)")
                        if document.duplicateStatus == .duplicate {
                            Text("Group size: \(document.duplicateGroupSize)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let contentHash = document.contentHash {
                        Text("SHA-256: \(contentHash)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    } else if let hashError = document.hashError {
                        Text("Hash error: \(hashError)")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }

            if !duplicateGroups.isEmpty {
                GroupBox("Duplicate groups") {
                    ForEach(duplicateGroups, id: \.key) { group in
                        DisclosureGroup(isExpanded: duplicateGroupExpansionBinding(for: group.key)) {
                            ForEach(group.value) { document in
                                Text(document.url.path(percentEncoded: false))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } label: {
                            Text("\(group.value.count) copies · \(group.key.prefix(12))")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    toggleDuplicateGroup(group.key)
                                }
                        }
                    }
                }
            }

            RecommendationReviewView()

            GroupBox("Development sample controls") {
                HStack {
                    Button("Add Sample Document") {
                        scanManager.addSampleDocument()
                    }
                    .disabled(scanManager.currentSession == nil)

                    Button("Remove Last Document") {
                        scanManager.removeSampleDocument()
                    }
                    .disabled(scanManager.documents.isEmpty)

                    Button("Clear Documents") {
                        scanManager.clearDocuments()
                    }
                    .disabled(scanManager.documents.isEmpty)
                }
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder]
        ) { result in
            do {
                let folder = try result.get()
                scanManager.addRootFolder(folder)
                scanError = nil
            } catch {
                scanError = error.localizedDescription
            }
        }
    }

    private var duplicateGroups: [(key: String, value: [DocumentRecord])] {
        Dictionary(grouping: scanManager.documents.filter {
            $0.duplicateStatus == .duplicate && $0.duplicateGroupIdentifier != nil
        }) { $0.duplicateGroupIdentifier! }
            .sorted { $0.key < $1.key }
    }

    private var rootFolderSectionTitle: String {
        let count = scanManager.selectedRootFolders.count
        return count == 0 ? "Root folders — none selected" : "Root folders — \(count) selected"
    }

    private func duplicateGroupExpansionBinding(for identifier: String) -> Binding<Bool> {
        Binding(
            get: { expandedDuplicateGroups.contains(identifier) },
            set: { isExpanded in
                if isExpanded {
                    expandedDuplicateGroups.insert(identifier)
                } else {
                    expandedDuplicateGroups.remove(identifier)
                }
            }
        )
    }

    private func toggleDuplicateGroup(_ identifier: String) {
        if expandedDuplicateGroups.contains(identifier) {
            expandedDuplicateGroups.remove(identifier)
        } else {
            expandedDuplicateGroups.insert(identifier)
        }
    }
}

#Preview {
    let inventory = Inventory()
    ContentView()
        .environment(ScanManager(inventory: inventory))
}
