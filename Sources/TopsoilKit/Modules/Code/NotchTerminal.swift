import AppKit
import Foundation
import SwiftTerm

/// A real VT/xterm terminal session, backed by SwiftTerm's `LocalProcessTerminalView`.
///
/// The previous implementation mirrored PTY bytes into a plain `NSTextView` after
/// stripping every ANSI escape — which cannot render full-screen TUIs like claude,
/// codex, or cursor-agent. SwiftTerm provides a complete emulator (cursor
/// addressing, alt-screen, colors, real keyboard input), so those agents run and
/// accept typing inside the notch.
@MainActor
public final class NotchTerminal: ObservableObject {
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var activeCLI: String?

    /// The emulator view embedded in SwiftUI. Persisted for the session's lifetime
    /// so the buffer and first-responder state survive view updates.
    public let terminalView: LocalProcessTerminalView

    public var onFocus: (() -> Void)?

    private let focusHandler = TerminalFocusHandler()

    @MainActor
    private final class TerminalFocusHandler: NSObject {
        weak var owner: NotchTerminal?

        @objc func focus(_ sender: NSClickGestureRecognizer) {
            guard let owner else { return }
            owner.focus()
        }
    }

    private let delegateProxy = ProcessDelegateProxy()

    public init() {
        terminalView = LocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 420, height: 260))
        focusHandler.owner = self
        let click = NSClickGestureRecognizer(target: focusHandler, action: #selector(TerminalFocusHandler.focus(_:)))
        // Let SwiftTerm keep handling selection and terminal mouse reporting.
        click.delaysPrimaryMouseButtonEvents = false
        terminalView.addGestureRecognizer(click)
        delegateProxy.owner = self
        terminalView.processDelegate = delegateProxy
        terminalView.getTerminal().changeScrollback(5_000)
        applyAppearance()
    }

    private func applyAppearance() {
        terminalView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.nativeForegroundColor = NSColor(srgbRed: 0.93, green: 0.94, blue: 0.96, alpha: 0.96)   // #EDEFF5
        terminalView.nativeBackgroundColor = .clear
        terminalView.installColors(Self.ansiPalette)
        applyAccent(NSColor(srgbRed: 0.36, green: 0.78, blue: 1.0, alpha: 1.0))                             // cyan until themed
    }

    /// Tints the caret and selection with the app's current accent so the terminal
    /// matches the notch theme. Called from the SwiftUI bridge as the accent changes.
    public func applyAccent(_ accent: NSColor) {
        terminalView.caretColor = accent.withAlphaComponent(0.95)
        terminalView.selectedTextBackgroundColor = accent.withAlphaComponent(0.22)
    }

    /// ANSI palette built from Topsoil's own colours — black panel + white text
    /// with the app's exact accent set (cyan hero, plus its blue/green/amber/red/
    /// purple accent choices) — so agent output reads as part of the app. Order:
    /// 8 normal (black,red,green,yellow,blue,magenta,cyan,white) then 8 bright.
    private static let ansiPalette: [SwiftTerm.Color] = [
        0x22252D, 0xFF6666, 0x66D98C, 0xFFB84D, 0x5C99FF, 0xAD73FF, 0x5CC7FF, 0xEDEFF5,
        0x4A4E5A, 0xFF8080, 0x85E6A5, 0xFFCB73, 0x85B2FF, 0xC79BFF, 0x85D6FF, 0xFFFFFF,
    ].map { hex in
        let r = UInt16((hex >> 16) & 0xFF), g = UInt16((hex >> 8) & 0xFF), b = UInt16(hex & 0xFF)
        return SwiftTerm.Color(red: r << 8 | r, green: g << 8 | g, blue: b << 8 | b)
    }

    // MARK: - Launch

    public func launch(tool: CodeCLITool) {
        let env = CodeCLIResolver.terminalEnvironment()
        guard let path = CodeCLIResolver.resolvedExecutablePath(for: tool, environment: env) else {
            presentMissingTool(tool)
            return
        }
        launch(command: CodeCLIResolver.quoteForShell(path), displayName: tool.displayName, environment: env)
    }

    public func launch(
        command: String,
        displayName: String,
        environment: [String: String] = CodeCLIResolver.terminalEnvironment()
    ) {
        GardenState.shared.onTerminalCommandRun()
        stop()
        activeCLI = displayName
        isRunning = true
        let envArray = environment.map { "\($0.key)=\($0.value)" }
        // An interactive login shell so ~/.zshrc (nvm/node, PATH, etc.) is sourced
        // before the CLI execs — required for codex's npx-based MCP servers.
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-ilc", command],
            environment: envArray
        )
    }

    // MARK: - I/O

    public func sendInput(_ text: String) {
        terminalView.send(txt: text)
    }

    public func scrollToLatest() {
        terminalView.scroll(toPosition: 1)
    }

    public func focus() {
        terminalView.window?.makeKey()
        terminalView.window?.makeFirstResponder(terminalView)
        onFocus?()
    }

    public func sendInterrupt() { sendInput("\u{03}") }

    public func stop() {
        if isRunning { terminalView.terminate() }
        isRunning = false
        activeCLI = nil
    }

    /// Plain-text snapshot of the current viewport — for diagnostics and tests.
    public func snapshotText() -> String {
        let terminal = terminalView.getTerminal()
        let cols = terminal.cols
        let rows = terminal.rows
        guard cols > 0, rows > 0 else { return "" }
        return terminal.getText(
            start: Position(col: 0, row: 0),
            end: Position(col: cols - 1, row: rows - 1)
        )
    }

    private func presentMissingTool(_ tool: CodeCLITool) {
        activeCLI = tool.displayName
        isRunning = false
        terminalView.feed(text: tool.missingHint + "\r\n")
    }

    fileprivate func processDidTerminate() {
        GardenState.shared.onSessionCodeSplitClose()
        isRunning = false
    }

    /// Bridges SwiftTerm's (non-isolated) delegate callbacks onto the main actor.
    private final class ProcessDelegateProxy: NSObject, LocalProcessTerminalViewDelegate {
        weak var owner: NotchTerminal?

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            Task { @MainActor [weak owner] in owner?.processDidTerminate() }
        }
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}
