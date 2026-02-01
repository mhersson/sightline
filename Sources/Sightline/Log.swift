import Foundation

enum Log {
    private static let logFile: String = {
        // Use XDG_STATE_HOME if set, otherwise fall back to ~/Library/Logs
        let stateDir: String
        if let xdgState = ProcessInfo.processInfo.environment["XDG_STATE_HOME"] {
            stateDir = (xdgState as NSString).expandingTildeInPath
        } else {
            stateDir = NSHomeDirectory() + "/Library/Logs"
        }

        let logDir = stateDir + "/Sightline"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        return logDir + "/debug.log"
    }()

    private static let fileHandle: FileHandle? = {
        FileManager.default.createFile(atPath: logFile, contents: nil)
        return FileHandle(forWritingAtPath: logFile)
    }()

    static func debug(_ message: String) {
        let line = "\(Date()): \(message)\n"
        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
            try? fileHandle?.synchronize()
        }
    }
}
