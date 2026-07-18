// 2026-07-18 21:59 SGT

import CryptoKit
import Foundation

enum DocumentContentHasher {
    static let algorithm = "SHA-256"
    nonisolated private static let chunkSize = 1_048_576

    nonisolated static func hash(fileAt url: URL) async throws -> String {
        try await Task.detached {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            var hasher = SHA256()
            while let data = try fileHandle.read(upToCount: chunkSize), !data.isEmpty {
                hasher.update(data: data)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
