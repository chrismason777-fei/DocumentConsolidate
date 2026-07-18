// 2026-07-18 19:24 SGT
//
//  ContentView.swift
//  DocumentConsolidate
//
//  Created by Hei Long Xia on 18/7/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(ScanManager.self) private var scanManager
    @Environment(Inventory.self) private var inventory

    var body: some View {
        VStack(spacing: 12) {
            Text("Document Consolidator")
                .font(.title)

            if let session = scanManager.currentSession {
                LabeledContent("Session identifier", value: session.id.uuidString)
                LabeledContent("Created") {
                    Text(session.createdAt, format: .dateTime)
                }
            } else {
                Text("No scan session")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Documents", value: inventory.documents.count.formatted())

            HStack {
                Button("New Scan Session") {
                    scanManager.createSession()
                }

                Button("Reset Scan Session") {
                    scanManager.resetSession()
                }
                .disabled(scanManager.currentSession == nil)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    let inventory = Inventory()
    ContentView()
        .environment(ScanManager(inventory: inventory))
        .environment(inventory)
}
