// 2026-07-21 10:37 SGT

import SwiftUI

enum WorkflowStage: String, CaseIterable, Identifiable {
    case prepareScan = "Prepare Scan"
    case recommendations = "Duplicate Archival"
    case executionPlan = "Archive Plan"

    var id: Self { self }

    var icon: String {
        switch self {
        case .prepareScan: "doc.text.magnifyingglass"
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
                    .fontWeight(.medium)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: stage.icon)
        }
    }
}
