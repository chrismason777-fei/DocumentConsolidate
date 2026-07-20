// 2026-07-20 19:53 SGT

import SwiftUI

struct WorkflowStageBanner: View {
    let stage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(stage).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.indigo)
            Text(title).font(.largeTitle.weight(.bold))
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct WorkflowMetricCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator.opacity(0.55)))
    }
}

struct WorkflowStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.11), in: Capsule())
    }
}

struct WorkflowOutcomeCard: View {
    let outcome: String
    let document: DocumentRecord
    let color: Color
    let isSelected: Bool
    var action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(alignment: .top, spacing: 12) {
                if action != nil {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .font(.title3).foregroundStyle(isSelected ? .indigo : .secondary)
                }
                Image(systemName: outcome == "KEEP" ? "doc.badge.checkmark.fill" : "archivebox.fill")
                    .font(.title3).foregroundStyle(color).frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.filename).font(.body.weight(.semibold))
                    Text(document.url.path(percentEncoded: false))
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                }
                Spacer()
                Text(outcome).font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(color)
            }
            .padding(14)
            .contentShape(Rectangle())
            .background(isSelected ? color.opacity(0.08) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? color : Color(nsColor: .separatorColor).opacity(0.5), lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(outcome), \(document.filename), \(document.url.path(percentEncoded: false))")
    }
}

struct WorkflowValidationRow: View {
    let label: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(.subheadline.weight(.medium))
            Spacer()
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(color)
        }
    }
}
