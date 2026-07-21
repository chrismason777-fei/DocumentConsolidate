// 2026-07-21 10:29 SGT

import SwiftUI

struct ProposalArchiveList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProposalStageHeader(
                eyebrow: "STAGE 5 OF 5",
                title: "Archive Plan",
                subtitle: "Review what stays, what would be archived, and what prevents safe execution."
            )
            HStack(spacing: 10) {
                ProposalMetric(value: "1", label: "Approved group", emphasis: .green)
                ProposalMetric(value: "1", label: "Planned archive", emphasis: .indigo)
                ProposalMetric(value: "No", label: "Execution ready", emphasis: .orange)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PLANNED ARCHIVAL").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Destination must be defined before execution.").font(.caption).foregroundStyle(.orange)
                }
                Spacer()
                Button("Refresh Validation", systemImage: "arrow.clockwise") { }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            List {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "archivebox.fill").font(.title3).foregroundStyle(.orange).frame(width: 24)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("GroupA-copy.txt").font(.body.weight(.semibold))
                        Text("Approved byte-identical duplicate").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ProposalBadge(text: "Destination not defined", color: .orange)
                }
                .padding(.vertical, 7)
                .listRowBackground(Color.indigo.opacity(0.08))
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationSplitViewColumnWidth(min: 390, ideal: 440, max: 520)
    }
}

struct ProposalArchiveDetail: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Group A archive operation").font(.title.weight(.bold))
                        Text("Approved for the plan; blocked from execution.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    ProposalBadge(text: "Attention required", color: .orange)
                }

                HStack(spacing: 12) {
                    ProposalReadinessCard(value: "Incomplete", label: "Plan validation", color: .orange)
                    ProposalReadinessCard(value: "No", label: "Execution ready", color: .orange)
                }

                Text("PLANNED OUTCOME").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                ProposalOutcomeCard(
                    outcome: "KEEP",
                    name: "GroupA-original.txt",
                    pathLabel: "Current location",
                    path: "~/Verification/GroupA-original.txt",
                    color: .indigo,
                    icon: "doc.badge.checkmark.fill"
                )
                ProposalOutcomeCard(
                    outcome: "ARCHIVE",
                    name: "GroupA-copy.txt",
                    pathLabel: "Source path",
                    path: "~/Verification/GroupA-copy.txt",
                    color: .orange,
                    icon: "archivebox.fill"
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("OPERATION DETAILS").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    ProposalLabelledValue(label: "Reason", value: "Byte-identical duplicate")
                    ProposalLabelledValue(label: "Archive destination", value: "Not defined", color: .orange)
                }
                .padding(16)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 11) {
                    Text("VALIDATION EVIDENCE").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    ProposalValidationCheck(label: "Source file exists", state: .verified)
                    ProposalValidationCheck(label: "Duplicate contents verified", state: .verified)
                    ProposalValidationCheck(label: "Destination defined", state: .unresolved)
                    Divider()
                    ProposalValidationCheck(label: "Plan valid", state: .unresolved)
                    ProposalValidationCheck(label: "Execution ready", value: "No", state: .unresolved)
                }
                .padding(16)
                .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                Label("Execution is unavailable because the archive destination is not defined.", systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Archive Plan is review-only. No filesystem action has occurred.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 700, alignment: .leading)
        }
        .navigationSplitViewColumnWidth(min: 420, ideal: 540)
    }
}

struct ProposalReadinessCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.25)))
    }
}

struct ProposalOutcomeCard: View {
    let outcome: String
    let name: String
    let pathLabel: String
    let path: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(name).font(.headline)
                    Spacer()
                    Text(outcome).font(.caption.weight(.bold)).tracking(1).foregroundStyle(color)
                }
                Text(pathLabel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(path).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .padding(16)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.28)))
    }
}

struct ProposalLabelledValue: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.body.weight(.medium)).foregroundStyle(color)
        }
    }
}

enum ProposalValidationState {
    case verified
    case unresolved
}

struct ProposalValidationCheck: View {
    let label: String
    var value: String?
    let state: ProposalValidationState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state == .verified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(state == .verified ? .green : .orange)
            Text(label).font(.subheadline.weight(.medium))
            Spacer()
            Text(value ?? (state == .verified ? "Verified" : "Unresolved"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(state == .verified ? .green : .orange)
        }
    }
}

#Preview("Archive Plan — attention required") {
    DuplicateArchivalRedesignPreview(initialStage: .archivePlan)
}
