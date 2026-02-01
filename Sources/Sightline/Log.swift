import Foundation

enum Log {
    private static let fileHandle: FileHandle? = {
        // Try directories in order of preference
        let candidates: [String] = {
            var dirs: [String] = []

            // 1. XDG_STATE_HOME if set
            if let xdgState = ProcessInfo.processInfo.environment["XDG_STATE_HOME"],
               !xdgState.isEmpty {
                dirs.append((xdgState as NSString).expandingTildeInPath + "/Sightline")
            }

            // 2. ~/Library/Logs (standard macOS location)
            dirs.append(NSHomeDirectory() + "/Library/Logs/Sightline")

            // 3. /tmp fallback
            dirs.append("/tmp")

            return dirs
        }()

        for dir in candidates {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                let path = dir + "/sightline_debug.log"
                if FileManager.default.createFile(atPath: path, contents: nil) {
                    return FileHandle(forWritingAtPath: path)
                }
            } catch {
                continue
            }
        }

        return nil
    }()

    static func debug(_ message: String) {
        guard let handle = fileHandle,
              let data = "\(Date()): \(message)\n".data(using: .utf8) else { return }
        handle.write(data)
        try? handle.synchronize()
    }
}
