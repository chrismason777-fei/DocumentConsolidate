// 2026-07-19 16:45 SGT

import SwiftUI

struct DocumentListView: View {
    let documents: [DocumentRecord]
    @Binding var selectedDocumentID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageHeading("Inventory", subtitle: "Select a document to inspect its metadata.")
            List(documents, selection: $selectedDocumentID) { document in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: document.duplicateStatus == .duplicate ? "doc.on.doc" : "doc")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(document.filename)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Text(document.displayDocumentType ?? "Pending")
                            Text(document.fileSize, format: .byteCount(style: .file))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tag(document.id)
            }
        }
        .padding()
        .navigationTitle("Inventory")
    }
}

struct DocumentDetailView: View {
    let document: DocumentRecord?

    var body: some View {
        DetailShell(title: document?.filename ?? "No document selected") {
            if let document {
                DetailField("Path", value: document.url.path(percentEncoded: false))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                    InventoryMetric("Type", value: document.displayDocumentType ?? "Awaiting analysis")
                    InventoryMetric("Category", value: document.category?.rawValue ?? "Uncategorised")
                    InventoryMetric("Size", value: document.fileSize.formatted(.byteCount(style: .file)))
                    InventoryMetric("Analysis", value: document.analysisStatus.rawValue)
                    InventoryMetric("Hash status", value: document.hashStatus.rawValue)
                    InventoryMetric("Duplicate status", value: document.duplicateStatus.rawValue)
                }
                if let hash = document.contentHash {
                    DetailField("SHA-256", value: hash, monospaced: true)
                }
                if let error = document.hashError {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
        }
    }
}

private struct InventoryMetric: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct DetailField: View {
    let label: String
    let value: String
    let monospaced: Bool

    init(_ label: String, value: String, monospaced: Bool = false) {
        self.label = label
        self.value = value
        self.monospaced = monospaced
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .body.monospaced() : .body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailShell<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.title2.weight(.semibold))
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }
}
