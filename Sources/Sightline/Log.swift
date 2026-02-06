import Foundation
import os.lock

enum Log {
    // Thread-safe file handle — Log.debug is called from both
    // the main thread and the capture dispatch queue
    private static let handle: OSAllocatedUnfairLock<FileHandle?> = {
        let logDir = NSHomeDirectory() + "/Library/Logs/Sightline"
        let logPath = logDir + "/sightline_debug.log"

        do {
            try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logPath) {
                FileManager.default.createFile(atPath: logPath, contents: nil)
            }
            let fh = FileHandle(forWritingAtPath: logPath)
            fh?.seekToEndOfFile()
            return OSAllocatedUnfairLock(initialState: fh)
        } catch {
            return OSAllocatedUnfairLock(initialState: nil)
        }
    }()

    static func debug(_ message: String) {
        guard let data = "\(Date()): \(message)\n".data(using: .utf8) else { return }
        handle.withLock { fh in
            fh?.write(data)
            try? fh?.synchronize()
        }
    }
}
