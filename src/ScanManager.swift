// 2026-07-18 19:14 SGT

import Foundation
import Observation

@MainActor
@Observable
final class ScanManager {
    private static let supportedExtensions: Set<String> = [
        "pdf", "docx", "xlsx", "pptx", "md", "txt", "rtf", "odt", "ods", "odp"
    ]

    private(set) var currentSession: ScanSession?
    private(set) var selectedRootFolders: [URL] = []
    @ObservationIgnored private var securityScopedRoots: [URL: URL] = [:]
    let inventory: Inventory

    init(inventory: Inventory) {
        self.inventory = inventory
    }

    var documents: [DocumentRecord] {
        inventory.documents
    }

    @discardableResult
    func createSession(for sourceFolders: [URL] = []) -> ScanSession {
        let session = ScanSession(sourceFolders: sourceFolders)
        inventory.reset(for: session.id)
        currentSession = session
        return session
    }

    func resetSession() {
        currentSession = nil
        inventory.reset(for: nil)
    }

    @discardableResult
    func addDocument(_ document: DocumentRecord) -> Bool {
        inventory.add(document)
    }

    func removeDocument(id: UUID) {
        inventory.remove(id: id)
    }

    func clearDocuments() {
        inventory.clear()
    }

    @discardableResult
    func addRootFolder(_ folder: URL) -> Bool {
        let canonicalFolder = Self.canonicalURL(for: folder)
        guard !selectedRootFolders.contains(canonicalFolder) else { return false }

        if folder.startAccessingSecurityScopedResource() {
            securityScopedRoots[canonicalFolder] = folder
        }
        selectedRootFolders.append(canonicalFolder)
        selectedRootFolders.sort { $0.path < $1.path }
        return true
    }

    func removeRootFolder(_ folder: URL) {
        let canonicalFolder = Self.canonicalURL(for: folder)
        selectedRootFolders.removeAll { $0 == canonicalFolder }
        if let scopedFolder = securityScopedRoots.removeValue(forKey: canonicalFolder) {
            scopedFolder.stopAccessingSecurityScopedResource()
        }
    }

    func clearRootFolders() {
        for folder in securityScopedRoots.values {
            folder.stopAccessingSecurityScopedResource()
        }
        securityScopedRoots.removeAll()
        selectedRootFolders.removeAll()
    }

    func scan() throws {
        let roots = selectedRootFolders.sorted { $0.path < $1.path }
        let session = createSession(for: roots)
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey
        ]

        var discoveredDocuments: [DocumentRecord] = []
        var discoveredURLs: Set<URL> = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys
            ) else {
                throw CocoaError(.fileReadUnknown)
            }

            for case let fileURL as URL in enumerator {
                let canonicalFileURL = Self.canonicalURL(for: fileURL)
                let fileExtension = canonicalFileURL.pathExtension.lowercased()
                guard Self.supportedExtensions.contains(fileExtension) else { continue }
                guard discoveredURLs.insert(canonicalFileURL).inserted else { continue }

                let values = try canonicalFileURL.resourceValues(forKeys: Set(keys))
                guard values.isRegularFile == true else { continue }

                discoveredDocuments.append(
                    DocumentRecord(
                        scanSessionID: session.id,
                        url: canonicalFileURL,
                        filename: canonicalFileURL.lastPathComponent,
                        fileExtension: fileExtension,
                        fileSize: Int64(values.fileSize ?? 0),
                        createdAt: values.creationDate,
                        modifiedAt: values.contentModificationDate
                    )
                )
            }
        }

        discoveredDocuments.sort { $0.url.path < $1.url.path }
        inventory.replace(with: discoveredDocuments)
    }

    func addSampleDocument() {
        guard let currentSession else { return }

        let url = URL(fileURLWithPath: "/tmp/sample-\(documents.count + 1).txt")
        let document = DocumentRecord(
            scanSessionID: currentSession.id,
            url: url,
            filename: url.lastPathComponent,
            fileExtension: url.pathExtension,
            fileSize: 1_024,
            createdAt: Date(),
            modifiedAt: Date()
        )
        addDocument(document)
    }

    func removeSampleDocument() {
        guard let document = documents.last else { return }
        removeDocument(id: document.id)
    }

    private static func canonicalURL(for url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
