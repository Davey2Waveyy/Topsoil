import AppKit
import SwiftUI

@MainActor
final class QuickTogglesModule: NotchModule {
    let id = "quickToggles"
    let title = "Quick Toggles"
    var isEnabled = true

    final class StateBox: ObservableObject {
        @Published var darkMode = false
        @Published var muted = false
        @Published var caffeinated = false
        @Published var dndActive = false
    }

    private let state = StateBox()
    private var caffeinateTask: Process?
    private var darkModeInFlight = false
    private var muteInFlight = false
    private var dndInFlight = false
    private var muteReadGeneration = 0

    // Observers — no polling timers at all.
    private var themeObserver: NSObjectProtocol?
    private var audioObserver: NSObjectProtocol?

    init() {
        snapshotState()
    }

    func collapsedView() -> AnyView? { nil }
    func expandedView() -> AnyView? { nil }
    func dashboardTile() -> AnyView? {
        AnyView(QuickTogglesDashboardTile(state: state, controller: self))
    }
    func wideBarView() -> AnyView? { nil }

    func activate() {
        snapshotState()
        guard themeObserver == nil, audioObserver == nil else { return }

        // Dark mode changes come via distributed notification — zero cost vs polling.
        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.state.darkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        }

        // Audio changes via workspace notification (fires on system volume/mute change).
        audioObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.sound.settingsChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshMute()
        }
    }

    func deactivate() {
        if let themeObserver { DistributedNotificationCenter.default().removeObserver(themeObserver) }
        if let audioObserver { DistributedNotificationCenter.default().removeObserver(audioObserver) }
        themeObserver = nil
        audioObserver = nil
    }

    func refresh() async { snapshotState() }

    // MARK: - Actions

    func toggleDarkMode() {
        guard !darkModeInFlight else { return }
        darkModeInFlight = true
        let previous = state.darkMode
        let target = !previous
        state.darkMode = target
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(target)
            end tell
        end tell
        """
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { Self.runScript(script) }.value
            guard let self else { return }
            self.darkModeInFlight = false
            if result == nil { self.state.darkMode = previous }
        }
    }

    func toggleMute() {
        guard !muteInFlight else { return }
        muteInFlight = true
        muteReadGeneration += 1
        let previous = state.muted
        state.muted.toggle()
        let script = "set volume output muted \(state.muted)"
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { Self.runScript(script) }.value
            guard let self else { return }
            self.muteInFlight = false
            if result == nil { self.state.muted = previous }
            self.refreshMute()
        }
    }

    func toggleCaffeinate() {
        if let task = caffeinateTask, task.isRunning {
            task.terminate()
            caffeinateTask = nil
            state.caffeinated = false
        } else {
            let task = Process()
            task.launchPath = "/usr/bin/caffeinate"
            task.arguments = ["-d"]
            do {
                try task.run()
                caffeinateTask = task
                state.caffeinated = true
            } catch {
                state.caffeinated = false
            }
        }
    }

    func toggleDoNotDisturb() {
        guard !dndInFlight else { return }
        // Requires Accessibility permission. Check first and guide if not granted.
        guard AXIsProcessTrusted() else {
            let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            return
        }

        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                try
                    if exists (menu bar item "Focus" of menu bar 1) then
                        click (menu bar item "Focus" of menu bar 1)
                        return
                    end if
                end try
                click (menu bar item "Control Center" of menu bar 1)
                delay 0.35
                try
                    set cc to window "Control Center"
                    set focusBtn to first button of cc whose description contains "Focus" or name contains "Focus"
                    click focusBtn
                    return
                end try
                key code 53
            end tell
        end tell
        """
        dndInFlight = true
        Task { [weak self] in
            _ = await Task.detached(priority: .userInitiated) { Self.runScript(script) }.value
            // Allow the menu bar to update after the script completes, without blocking UI.
            try? await Task.sleep(for: .milliseconds(700))
            guard let self else { return }
            self.dndInFlight = false
            self.refreshDND()
        }
    }

    // MARK: - Private

    private func snapshotState() {
        state.darkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        state.caffeinated = caffeinateTask?.isRunning == true
        refreshMute()
        refreshDND()
    }

    private func refreshMute() {
        guard !muteInFlight else { return }
        muteReadGeneration += 1
        let generation = muteReadGeneration
        Task.detached(priority: .utility) { [weak self] in
            let script = "output muted of (get volume settings)"
            let result = Self.runScript(script)
            await MainActor.run { [weak self] in
                guard let self, self.muteReadGeneration == generation, !self.muteInFlight else { return }
                if let result { self.state.muted = result.contains("true") }
            }
        }
    }

    private func refreshDND() {
        guard AXIsProcessTrusted() else { return }
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                return exists (menu bar item "Focus" of menu bar 1)
            end tell
        end tell
        """
        Task.detached(priority: .utility) { [weak self] in
            let result = Self.runScript(script)
            await MainActor.run { [weak self] in
                self?.state.dndActive = result?.contains("true") ?? false
            }
        }
    }

    @discardableResult
    private nonisolated static func runScript(_ source: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", source]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
