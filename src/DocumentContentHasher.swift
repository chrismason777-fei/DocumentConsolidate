// 2026-07-19 16:55 SGT

import CryptoKit
import Foundation

enum DocumentContentHasher {
    static let algorithm = "SHA-256"
    nonisolated private static let chunkSize = 1_048_576

    nonisolated static func hash(fileAt url: URL) async throws -> String {
        let hashingTask = Task.detached {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }

            var hasher = SHA256()
            while let data = try fileHandle.read(upToCount: chunkSize), !data.isEmpty {
                try Task.checkCancellation()
                hasher.update(data: data)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }
        return try await withTaskCancellationHandler {
            try await hashingTask.value
        } onCancel: {
            hashingTask.cancel()
        }
    }
}
