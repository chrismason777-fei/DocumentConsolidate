// 2026-07-19 17:25 SGT

import SwiftUI

enum WorkflowStage: String, CaseIterable, Identifiable {
    case scanRoots = "Scan Folders"
    case scan = "Scan"
    case inventory = "Inventory"
    case duplicates = "Duplicates"
    case recommendations = "Duplicate Archival"
    case executionPlan = "Archive Plan"

    var id: Self { self }

    var icon: String {
        switch self {
        case .scanRoots: "folder.badge.plus"
        case .scan: "waveform.path.ecg"
        case .inventory: "doc.text.magnifyingglass"
        case .duplicates: "doc.on.doc"
        case .recommendations: "checklist"
        case .executionPlan: "list.bullet.rectangle"
        }
    }
}

struct WorkflowStageRow: View {
    let stage: WorkflowStage
    let status: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.rawValue)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: stage.icon)
        }
    }
}
