import Foundation

enum Log {
    private static let fileHandle: FileHandle? = {
        let logDir = NSHomeDirectory() + "/Library/Logs/Sightline"
        let logPath = logDir + "/sightline_debug.log"

        do {
            try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: logPath, contents: nil)
            return FileHandle(forWritingAtPath: logPath)
        } catch {
            return nil
        }
    }()

    static func debug(_ message: String) {
        guard let handle = fileHandle,
              let data = "\(Date()): \(message)\n".data(using: .utf8) else { return }
        handle.write(data)
        try? handle.synchronize()
    }
}
