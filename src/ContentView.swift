// 2026-07-18 18:31 SGT
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
                Text("Scan session \(session.id.uuidString)")
            } else {
                Text("No scan session")
                    .foregroundStyle(.secondary)
            }

            Text("\(inventory.documents.count) documents")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    let inventory = Inventory()
    ContentView()
        .environment(ScanManager(inventory: inventory))
        .environment(inventory)
}
