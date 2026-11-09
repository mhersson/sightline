import Foundation
import os

/// Appends to ~/Library/Logs/Sightline/sightline_debug.log.
/// Called from the main thread and from ScreenCaptureKit's callback queues, so writes are serialized.
enum Log {
    private static let handle: OSAllocatedUnfairLock<FileHandle?> = {
        let directory = URL.libraryDirectory.appending(path: "Logs/Sightline")
        let file = directory.appending(path: "sightline_debug.log")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: file)
        _ = try? handle?.seekToEnd()
        return OSAllocatedUnfairLock(initialState: handle)
    }()

    static func debug(_ message: String) {
        let line = Data("\(Date()): \(message)\n".utf8)
        handle.withLock { try? $0?.write(contentsOf: line) }
    }
}
