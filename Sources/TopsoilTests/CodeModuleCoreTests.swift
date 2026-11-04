import AppKit
import Foundation
import TopsoilKit

@MainActor
private func waitForCodeModuleCondition(
    timeout: TimeInterval = 1.5,
    _ predicate: @escaping () -> Bool
) -> Bool {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while Date() < deadline {
        if predicate() { return true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }
    return predicate()
}

func codeModuleCoreTests() {
    // ---- CodeCLITool / split panes ----
    test("code cli: dashboard uses three fixed split panes") {
        let tools = CodeCLITool.allCases
        expectEqual(tools.map(\.rawValue), ["claude", "codex", "cursor"], "tool order")
        expectEqual(CodeTerminalPaneDescriptor.defaultPanes.map(\.tool), tools, "one pane per tool")
    }

    test("code cli: pane descriptors expose launch commands and display names") {
        let panes = CodeTerminalPaneDescriptor.defaultPanes
        expectEqual(panes[0].displayName, "Claude", "claude title")
        expectEqual(panes[1].command, "codex", "codex command")
        expectEqual(panes[2].id, "cursor", "cursor id")
    }

    test("code cli: tools expose app bundle candidates for real icon rendering") {
        expectEqual(CodeCLITool.claude.appIconCandidatePaths, ["/Applications/Claude.app"], "claude app icon path")
        expectEqual(CodeCLITool.codex.appIconCandidatePaths, ["/Applications/Codex.app"], "codex app icon path")
        expectEqual(CodeCLITool.cursor.appIconCandidatePaths, ["/Applications/Cursor.app"], "cursor app icon path")
    }

    test("code cli: cursor resolves to the cursor-agent CLI, not the GUI launcher") {
        // The bundled `cursor` only opens the GUI editor; the interactive agent is `cursor-agent`.
        let agentPath = "/Users/example/.local/bin/cursor-agent"
        let command = CodeCLIResolver.resolvedShellCommand(
            for: .cursor,
            environment: ["PATH": "/usr/bin:/bin"],
            homeDirectory: URL(fileURLWithPath: "/Users/example"),
            isExecutable: { $0 == agentPath }
        )
        expectEqual(command, agentPath, "cursor uses cursor-agent")
        expectEqual(CodeCLITool.cursor.executableName, "cursor-agent", "cursor executable is cursor-agent")
    }

    test("code cli: resolver returns nil when a tool isn't installed") {
        let missing = CodeCLIResolver.resolvedExecutablePath(
            for: .cursor,
            environment: ["PATH": "/usr/bin:/bin"],
            homeDirectory: URL(fileURLWithPath: "/Users/example"),
            isExecutable: { _ in false }
        )
        expect(missing == nil, "unresolved tool returns nil so the UI can show an install hint")
    }

    test("code cli: terminal environment includes user and app CLI paths") {
        let env = CodeCLIResolver.terminalEnvironment(
            from: ["PATH": "/usr/bin:/bin"],
            homeDirectory: URL(fileURLWithPath: "/Users/example")
        )
        let pathParts = env["PATH"]?.split(separator: ":").map(String.init) ?? []
        expect(pathParts.contains("/Users/example/.local/bin"), "home .local/bin is included")
        expect(pathParts.contains("/Applications/Cursor.app/Contents/Resources/app/bin"), "Cursor CLI path is included")
        expect(pathParts.contains("/Applications/Codex.app/Contents/Resources"), "Codex CLI path is included")
        expect(pathParts.contains("/usr/bin"), "original PATH is preserved")
    }

    test("terminal: clicking can acquire keyboard focus in the notch panel") {
        MainActor.assumeIsolated {
            let terminal = NotchTerminal()
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.becomesKeyOnlyIfNeeded = true
            panel.contentView = terminal.terminalView
            panel.makeFirstResponder(nil)
            let click = terminal.terminalView.gestureRecognizers.compactMap { $0 as? NSClickGestureRecognizer }.first
            expect(click != nil, "terminal installs a native click focus handler")
            if let click, let action = click.action {
                _ = click.target?.perform(action, with: click)
            }
            expect(panel.firstResponder === terminal.terminalView,
                   "clicking the terminal restores the keyboard responder")
        }
    }

    test("terminal: retains long scrollback and can return to latest output") {
        MainActor.assumeIsolated {
            let terminal = NotchTerminal()
            for line in 0..<700 { terminal.terminalView.feed(text: "line-\(line)\r\n") }
            terminal.terminalView.scroll(toPosition: 0)
            expect(terminal.snapshotText().contains("line-0"), "early output remains beyond 500 lines")
            terminal.scrollToLatest()
            expect(terminal.terminalView.scrollPosition == 1, "latest control returns viewport to bottom")
        }
    }

    test("terminal: SwiftTerm PTY renders process output and forwards typed input") {
        MainActor.assumeIsolated {
            let terminal = NotchTerminal()
            let env = CodeCLIResolver.terminalEnvironment(from: ["PATH": "/usr/bin:/bin"])
            // `cat` echoes whatever we type back through the PTY into the emulator buffer.
            terminal.launch(command: "cat", displayName: "input-test", environment: env)
            expect(terminal.isRunning, "session reports running after launch")

            terminal.sendInput("notch-roundtrip\r")
            let echoed = waitForCodeModuleCondition {
                terminal.snapshotText().contains("notch-roundtrip")
            }
            expect(echoed, "typed input round-trips through the SwiftTerm PTY")
            terminal.stop()
        }
    }

    test("code cli: missing-tool hint tells the user how to install cursor-agent") {
        expect(CodeCLITool.cursor.missingHint.contains("cursor.com/install"),
               "cursor hint includes the install command")
        expect(CodeCLITool.claude.missingHint.contains("claude"), "claude hint names the tool")
    }

    // ---- GitStatusParser ----
    test("git: parses branch, ahead/behind, and dirty flag") {
        let output = "## main...origin/main [ahead 1, behind 2]\n M file.swift\n?? new.txt"
        let status = GitStatusParser.parse(output)
        expect(status.branch == "main", "branch is main")
        expect(status.isDirty, "working tree is dirty")
        expectEqual(status.ahead, 1, "ahead count")
        expectEqual(status.behind, 2, "behind count")
    }

    test("git: clean repo with no upstream") {
        let status = GitStatusParser.parse("## feature/login")
        expect(status.branch == "feature/login", "branch parsed")
        expect(!status.isDirty, "clean")
        expectEqual(status.ahead, 0, "no ahead")
        expectEqual(status.behind, 0, "no behind")
    }

    test("git: detached HEAD has no branch") {
        let status = GitStatusParser.parse("## HEAD (no branch)\n M f.swift")
        expect(status.branch == nil, "no branch when detached")
        expect(status.isDirty, "dirty")
    }

    test("git: empty output is unknown") {
        expectEqual(GitStatusParser.parse(""), GitStatus.unknown, "empty parses to unknown")
    }

    // ---- LaunchCommandBuilder ----
    test("launch: editor command runs the editor CLI with the path") {
        let cmd = LaunchCommandBuilder.command(for: .editor, path: "/tmp/proj")
        expectEqual(cmd.executable, "/usr/bin/env", "uses env")
        expect(cmd.arguments == ["code", "/tmp/proj"], "code <path>")
    }

    test("launch: terminal and reveal use open") {
        expect(LaunchCommandBuilder.command(for: .terminal, path: "/tmp/p").arguments == ["-a", "Terminal", "/tmp/p"], "open -a Terminal")
        expect(LaunchCommandBuilder.command(for: .reveal, path: "/tmp/p").arguments == ["-R", "/tmp/p"], "open -R")
    }

    test("launch: claude code opens Terminal running claude in the path") {
        let cmd = LaunchCommandBuilder.command(for: .claudeCode, path: "/tmp/my proj")
        expectEqual(cmd.executable, "/usr/bin/osascript", "uses osascript")
        expect(cmd.arguments.first == "-e", "passes a script")
        let script = cmd.arguments.last ?? ""
        expect(script.contains("claude"), "runs claude")
        expect(script.contains("'/tmp/my proj'"), "cd's into the quoted path")
        expect(script.contains("do script"), "uses Terminal do script")
    }

    test("launch: shell single-quoting escapes embedded quotes") {
        expectEqual(LaunchCommandBuilder.shellSingleQuote("/a b"), "'/a b'", "spaces wrapped")
        expectEqual(LaunchCommandBuilder.shellSingleQuote("it's"), "'it'\\''s'", "apostrophe escaped")
    }

    // ---- CodeProjectStore ----
    func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    }
    func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    test("code store: pin persists and resolves the folder") {
        let storeURL = tempStoreURL()
        let folder = tempDir()
        let a = CodeProjectStore(url: storeURL)
        a.add(folder)
        expect(a.projects.count == 1, "one project pinned")
        expect(a.projects.first?.name == folder.lastPathComponent, "name captured")

        let b = CodeProjectStore(url: storeURL)
        expect(b.projects.count == 1, "survives reload")
        expect(b.resolve(b.projects[0])?.standardizedFileURL.path == folder.standardizedFileURL.path, "resolves to folder")
    }

    test("code store: pinning the same folder twice is ignored") {
        let store = CodeProjectStore(url: tempStoreURL())
        let folder = tempDir()
        store.add(folder)
        store.add(folder)
        expect(store.projects.count == 1, "deduped")
    }

    test("code store: remove drops the project") {
        let store = CodeProjectStore(url: tempStoreURL())
        store.add(tempDir())
        store.remove(at: 0)
        expect(store.projects.isEmpty, "removed")
    }
}
