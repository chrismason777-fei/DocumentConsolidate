// 2026-07-24 16:23 SGT

import SwiftUI
import UniformTypeIdentifiers

struct ArchiveDestinationSection: View {
    @Environment(ScanManager.self) private var scanManager
    @Binding var errorMessage: String?
    @State private var isPickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ARCHIVE DESTINATION")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
            if let destination = scanManager.inventory.archiveDestination {
                destinationDetails(destination)
            } else {
                Text("No archive destination selected.")
                    .foregroundStyle(.secondary)
                Button("Choose Destination…", systemImage: "folder.badge.plus") {
                    isPickerPresented = true
                }
                .buttonStyle(.bordered)
                .disabled(actionsDisabled)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .fileImporter(isPresented: $isPickerPresented, allowedContentTypes: [.folder]) { result in
            handlePickerResult(result)
        }
    }

    private func destinationDetails(_ destination: ArchiveDestination) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(destination.canonicalRootURL.lastPathComponent, systemImage: "folder.fill")
                .font(.headline)
            Text(destination.displayPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            ViewThatFits(in: .horizontal) {
                HStack { destinationActions }
                VStack(alignment: .leading) { destinationActions }
            }
        }
    }

    @ViewBuilder private var destinationActions: some View {
        Button("Change Destination…", systemImage: "folder.badge.gearshape") {
            isPickerPresented = true
        }
        .buttonStyle(.bordered)
        .disabled(actionsDisabled)
        Button("Clear Destination", systemImage: "xmark.circle") {
            clearDestination()
        }
        .buttonStyle(.bordered)
        .disabled(actionsDisabled)
    }

    private var actionsDisabled: Bool {
        scanManager.currentSession == nil || scanManager.inventory.isGeneratingExecutionPlan
    }

    private func handlePickerResult(_ result: Result<URL, Error>) {
        switch result {
        case let .success(selectedURL):
            do {
                let destination = try ArchiveDestinationAccess().authorize(
                    selectedURL: selectedURL,
                    scanRoots: scanManager.selectedRootFolders
                )
                errorMessage = nil
                Task {
                    errorMessage = ArchiveDestinationPresentation.message(
                        for: await scanManager.generateExecutionPlan(for: destination)
                    )
                }
            } catch let error as ArchiveDestinationAccessError {
                errorMessage = ArchiveDestinationPresentation.message(for: error)
            } catch {
                errorMessage = "The selected Archive Destination could not be authorized."
            }
        case let .failure(error):
            guard (error as NSError).code != NSUserCancelledError else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func clearDestination() {
        Task {
            errorMessage = ArchiveDestinationPresentation.message(
                for: await scanManager.clearArchiveDestination()
            )
        }
    }
}

enum ArchiveDestinationPresentation {
    static func message(
        for result: Result<ArchivePlanningState, ArchivePlanningLifecycleError>
    ) -> String? {
        guard case let .failure(error) = result else { return nil }
        switch error {
        case .noScanSession:
            return "Complete a scan before configuring the Archive Destination."
        case .cancelled:
            return "Archive Plan preparation was cancelled."
        case let .destinationAccess(error):
            return message(for: error)
        case .destinationAccessFailed:
            return "The Archive Destination could not be accessed."
        case .validationFailed:
            return "The proposed Archive Plan failed validation. The existing destination and plan were preserved."
        case .staleGeneration:
            return "A newer Archive Plan request replaced this request."
        }
    }

    static func message(for error: ArchiveDestinationAccessError) -> String {
        switch error {
        case .notFileURL, .doesNotExist, .notDirectory, .inaccessibleDirectory:
            "Select an existing, accessible folder for the Archive Destination."
        case .notWritable:
            "The Archive Destination is not writable. Choose a folder that allows read-write access."
        case .equalsScanRoot, .insideScanRoot:
            "The Archive Destination must be outside all scanned folders."
        case .scopedAccessAcquisitionFailed:
            "Access to the Archive Destination was denied."
        case .bookmarkCreationFailed, .bookmarkResolutionFailed:
            "Authorization for the Archive Destination could not be saved or restored."
        case .staleBookmark:
            "Authorization for the Archive Destination is stale. Choose the folder again."
        }
    }
}
