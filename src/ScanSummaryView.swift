// 2026-07-19 13:10 SGT

import SwiftUI

struct ScanSummaryView: View {
    let session: ScanSession

    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 12, alignment: .topLeading)
    ]

    var body: some View {
        GroupBox("Scan summary") {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    SummaryMetric("Created") {
                        Text(session.createdAt, format: .dateTime.month().day().hour().minute())
                    }
                    SummaryMetric("Scanned roots", value: session.sourceFolders.count.formatted())
                    SummaryMetric("Unique documents", value: session.uniqueDocumentCount.formatted())
                    SummaryMetric("Duplicate documents", value: session.duplicateDocumentCount.formatted())
                    SummaryMetric("Duplicate groups", value: session.duplicateGroupCount.formatted())
                    SummaryMetric("Duplicate analysis", value: session.duplicateAnalysisStatus.rawValue)
                }

                Text("Session \(session.id.uuidString)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct SummaryMetric<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, value: String) where Content == Text {
        self.label = label
        self.content = Text(value)
    }

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

