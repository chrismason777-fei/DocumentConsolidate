// 2026-07-18 19:00 SGT
//
//  DocumentConsolidateApp.swift
//  DocumentConsolidate
//
//  Created by Hei Long Xia on 18/7/26.
//

import SwiftUI

@main
struct DocumentConsolidateApp: App {
    @State private var scanManager: ScanManager

    init() {
        let inventory = Inventory()
        _scanManager = State(initialValue: ScanManager(inventory: inventory))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(scanManager)
        }
    }
}
