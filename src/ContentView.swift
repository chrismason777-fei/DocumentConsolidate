// 2026-07-18 19:14 SGT
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
            } else {
                Text("No scan session")
                    .foregroundStyle(.secondary)
            }

            GroupBox("Selected root folders") {
                if scanManager.selectedRootFolders.isEmpty {
                    Text("No folders selected")
                        .foregroundStyle(.secondary)
                } else {
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
            }

            LabeledContent("Documents", value: scanManager.documents.count.formatted())

            HStack {
                Button("Add Root Folder") {
                    isFolderPickerPresented = true
                }

                Button("Clear Root Folders") {
                    scanManager.clearRootFolders()
                }
                .disabled(scanManager.selectedRootFolders.isEmpty)

                Button("Scan Selected Folders") {
                    do {
                        try scanManager.scan()
                        scanError = nil
                    } catch {
                        scanError = error.localizedDescription
                    }
                }
                .disabled(scanManager.selectedRootFolders.isEmpty)

                Button("Reset Scan Session") {
                    scanManager.resetSession()
                }
                .disabled(scanManager.currentSession == nil)
            }

            if let scanError {
                Text(scanError)
                    .foregroundStyle(.red)
            }

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
}

#Preview {
    let inventory = Inventory()
    ContentView()
        .environment(ScanManager(inventory: inventory))
}
