// 2026-07-20 13:24 SGT

import SwiftUI

struct DuplicateGroupSummary: Identifiable {
    let id: String
    let documents: [DocumentRecord]

    var displayName: String {
        documents.first?.filename ?? "Duplicate Group"
    }

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
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Duplicate Groups",
                    systemImage: "doc.on.doc",
                    description: Text("Byte-identical groups found during a scan will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(groups, selection: $selectedGroupID) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.displayName)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Spacer()
                            Text("\(group.documents.count) copies")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
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
        DetailShell(title: group?.displayName ?? "No duplicate group selected") {
            if let group {
                HStack {
                    Label("Verified byte-identical", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(group.documents.count) copies")
                        .foregroundStyle(.secondary)
                }
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
                Divider()
                DetailField("Content hash", value: group.id, monospaced: true)
            }
        }
    }
}
