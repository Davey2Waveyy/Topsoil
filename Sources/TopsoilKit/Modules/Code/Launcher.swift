import Foundation

/// Runs `LaunchCommand`s. The editor action falls back to `open <path>` when the
/// editor CLI isn't installed.
public enum Launcher {
    /// Launches a command. Returns the exit status when `waitForExit` is true, else 0
    /// on a successful spawn, or nil if the process couldn't be started.
    @discardableResult
    public static func run(_ command: LaunchCommand, waitForExit: Bool = false) -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        guard waitForExit else { return 0 }
        process.waitUntilExit()
        return process.terminationStatus
    }

    public static func perform(_ action: CodeAction, path: String) {
        let command = LaunchCommandBuilder.command(for: action, path: path)

        if action == .editor {
            // `env <cli> <path>` exits non-zero (e.g. 127) when the CLI isn't on PATH.
            DispatchQueue.global(qos: .userInitiated).async {
                let status = run(command, waitForExit: true)
                if status != 0 {
                    run(LaunchCommand(executable: "/usr/bin/open", arguments: [path]))
                }
            }
        } else {
            run(command)
        }
    }
}
