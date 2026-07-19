// 2026-07-19 16:55 SGT

extension ScanManager {
    func stopScan() {
        stopRequested = true
        activeHashTask?.cancel()
    }

    func resetSession() async {
        stopScan()
        while isScanning {
            await Task.yield()
        }
        clearSessionState()
    }
}

