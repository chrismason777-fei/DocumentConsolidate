// 2026-07-18 21:59 SGT

import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class ScanManager {
    private static let supportedExtensions: Set<String> = [
        "pdf", "docx", "xlsx", "pptx", "md", "txt", "rtf", "odt", "ods", "odp"
    ]

    private(set) var currentSession: ScanSession?
    private(set) var selectedRootFolders: [URL] = []
    private(set) var analysisCompletedCount = 0
    private(set) var analysisTotalCount = 0
    private(set) var hashCompletedCount = 0
    private(set) var hashTotalCount = 0
    private(set) var isScanning = false
    private(set) var isAnalysing = false
    private(set) var isHashing = false
    private var stopRequested = false
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

    func scan() async throws {
        guard !isScanning else { return }
        isScanning = true
        stopRequested = false
        defer { isScanning = false }

        let roots = selectedRootFolders.sorted { $0.path < $1.path }
        let session = createSession(for: roots)
        let discoveredDocuments = try await enumerateDocuments(in: roots, sessionID: session.id)
        inventory.replace(with: discoveredDocuments)
        guard !stopRequested else { return }
        try await analyseDocuments()
        guard !stopRequested else { return }
        await hashDocuments()
    }

    func stopScan() {
        stopRequested = true
    }

    private func enumerateDocuments(in roots: [URL], sessionID: UUID) async throws -> [DocumentRecord] {
        var discoveredDocuments: [DocumentRecord] = []
        var discoveredURLs: Set<URL> = []
        let fileURLs = try await Task.detached {
            try Self.enumeratedFileURLs(in: roots)
        }.value

        for canonicalFileURL in fileURLs {
            guard !stopRequested else { break }
            guard discoveredURLs.insert(canonicalFileURL).inserted else { continue }
            let values = try canonicalFileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            discoveredDocuments.append(
                DocumentRecord(
                    scanSessionID: sessionID,
                    url: canonicalFileURL,
                    filename: canonicalFileURL.lastPathComponent,
                    fileExtension: canonicalFileURL.pathExtension.lowercased(),
                    fileSize: 0,
                    createdAt: nil,
                    modifiedAt: nil
                )
            )
            await Task.yield()
        }

        discoveredDocuments.sort { $0.url.path < $1.url.path }
        return discoveredDocuments
    }

    private func analyseDocuments() async throws {
        analysisCompletedCount = 0
        analysisTotalCount = documents.count
        isAnalysing = true
        defer { isAnalysing = false }

        for document in documents {
            guard !stopRequested else { break }
            var analysedDocument = document
            analysedDocument.analysisStatus = .analysing
            inventory.update(analysedDocument)
            await Task.yield()

            do {
                let values = try document.url.resourceValues(forKeys: [
                    .fileSizeKey,
                    .creationDateKey,
                    .contentModificationDateKey
                ])
                let type = UTType(filenameExtension: document.fileExtension)
                analysedDocument.fileSize = Int64(values.fileSize ?? 0)
                analysedDocument.createdAt = values.creationDate
                analysedDocument.modifiedAt = values.contentModificationDate
                analysedDocument.isSupported = Self.supportedExtensions.contains(document.fileExtension)
                analysedDocument.hashStatus = analysedDocument.isSupported == true ? .pending : .notRequired
                analysedDocument.category = Self.category(for: document.fileExtension)
                analysedDocument.displayDocumentType = type?.localizedDescription
                    ?? (document.fileExtension.isEmpty ? "Unknown" : document.fileExtension.uppercased())
                analysedDocument.analysedAt = Date()
                analysedDocument.analysisStatus = .complete
            } catch {
                analysedDocument.analysedAt = Date()
                analysedDocument.analysisStatus = .failed
            }

            inventory.update(analysedDocument)
            analysisCompletedCount += 1
            await Task.yield()
        }
    }

    private func hashDocuments() async {
        let supportedDocuments = documents.filter {
            $0.analysisStatus == .complete && $0.isSupported == true
        }
        hashCompletedCount = 0
        hashTotalCount = supportedDocuments.count
        isHashing = true
        defer { isHashing = false }

        for document in supportedDocuments {
            guard !stopRequested else { break }
            var hashedDocument = document
            hashedDocument.hashStatus = .hashing
            hashedDocument.hashAlgorithm = DocumentContentHasher.algorithm
            inventory.update(hashedDocument)
            await Task.yield()

            do {
                hashedDocument.contentHash = try await DocumentContentHasher.hash(fileAt: document.url)
                hashedDocument.hashStatus = .complete
            } catch {
                hashedDocument.hashError = error.localizedDescription
                hashedDocument.hashStatus = .failed
            }
            hashedDocument.hashedAt = Date()
            inventory.update(hashedDocument)
            hashCompletedCount += 1
            await Task.yield()
        }
    }

    private static func canonicalURL(for url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    nonisolated private static func enumeratedFileURLs(in roots: [URL]) throws -> [URL] {
        var fileURLs: [URL] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey]
            ) else {
                throw CocoaError(.fileReadUnknown)
            }
            fileURLs.append(contentsOf: enumerator.compactMap { ($0 as? URL)?.standardizedFileURL.resolvingSymlinksInPath() })
        }
        return fileURLs
    }

    private static func category(for fileExtension: String) -> DocumentCategory {
        switch fileExtension {
        case "pdf", "docx", "odt", "rtf": .document
        case "xlsx", "ods": .spreadsheet
        case "pptx", "odp": .presentation
        case "md", "txt": .text
        default: .other
        }
    }
}
