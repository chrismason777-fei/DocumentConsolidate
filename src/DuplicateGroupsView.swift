// 2026-07-19 17:25 SGT

import SwiftUI

struct DuplicateGroupSummary: Identifiable {
    let id: String
    let documents: [DocumentRecord]

    var folderPaths: String {
        Set(documents.map { $0.url.deletingLastPathComponent().path(percentEncoded: false) })
            .sorted()
            .joined(separator: ", ")
    }
}

struct DuplicateGroupsView: View {
    let groups: [DuplicateGroupSummary]
    @Binding var selectedGroupID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageHeading("Duplicate groups", subtitle: "Select a group to review its documents.")
            List(groups, selection: $selectedGroupID) { group in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(group.id.prefix(12)).font(.body.monospaced())
                        Spacer()
                        Text("\(group.documents.count) copies").foregroundStyle(.secondary)
                    }
                    Text(group.folderPaths)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .tag(group.id)
            }
        }
        .padding()
        .navigationTitle("Duplicates")
    }

    static func groups(from documents: [DocumentRecord]) -> [DuplicateGroupSummary] {
        Dictionary(grouping: documents.filter {
            $0.duplicateStatus == .duplicate && $0.duplicateGroupIdentifier != nil
        }) { $0.duplicateGroupIdentifier! }
            .map { DuplicateGroupSummary(id: $0.key, documents: $0.value.sorted { $0.url.path < $1.url.path }) }
            .sorted { $0.id < $1.id }
    }
}

struct DuplicateGroupDetailView: View {
    let group: DuplicateGroupSummary?

    var body: some View {
        DetailShell(title: group.map { "Duplicate group \($0.id.prefix(12))" } ?? "No duplicate group selected") {
            if let group {
                DetailField("SHA-256", value: group.id, monospaced: true)
                DetailField("Locations", value: group.folderPaths)
                Divider()
                ForEach(group.documents) { document in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(document.filename, systemImage: document.hasApprovedDefinitiveCopyEvidence ? "checkmark.circle" : "doc")
                        Text(document.url.path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
