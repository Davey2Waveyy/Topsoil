import Foundation
import TopsoilKit

func codeProcessRegressionTests() {
    test("launch: large discarded output cannot block process completion") {
        let command = LaunchCommand(executable: "/bin/sh", arguments: [
            "-c", "dd if=/dev/zero bs=1024 count=256 2>/dev/null; dd if=/dev/zero bs=1024 count=256 1>&2 2>/dev/null; exit 7"
        ])
        expectEqual(Launcher.run(command, waitForExit: true), 7,
                    "large stdout and stderr are discarded and exit status survives")
    }

    test("git probe: drains status output larger than the pipe buffer") {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("topsoil-git-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let initialized = Launcher.run(LaunchCommand(executable: "/usr/bin/git", arguments: [
                "-C", directory.path, "init", "--quiet"
            ]), waitForExit: true)
            expectEqual(initialized, 0, "temporary repository initialized")
            for index in 0..<1200 {
                let filename = "file-\(index)-" + String(repeating: "x", count: 180)
                try Data().write(to: directory.appendingPathComponent(filename))
            }
            let status = GitProbe.status(atPath: directory.path)
            expect(status.isDirty, "large untracked listing returns a dirty status")
            expect(status.branch != nil, "branch remains available")
        } catch {
            expect(false, "temporary repository fixture failed: \(error)")
        }
    }
}
