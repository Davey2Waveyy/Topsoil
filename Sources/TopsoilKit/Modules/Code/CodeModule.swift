import SwiftUI

@MainActor
final class CodeModule: NotchModule {
    let id = "code"
    let title = "Code"
    var isEnabled = true
    var isFullPageTile: Bool { true }

    final class StateBox: ObservableObject {
        @Published var projects: [CodeProjectDisplay] = []
    }

    private let state = StateBox()
    private let terminals = Dictionary(
        uniqueKeysWithValues: CodeCLITool.allCases.map { ($0, NotchTerminal()) }
    )
    private let store = CodeProjectStore(url: CodeProjectStore.defaultURL())
    private var timer: Timer?
    private var isRefreshing = false
    private var refreshRequested = false
    private var refreshGeneration = 0

    init() {
        state.projects = store.projects.map { CodeProjectDisplay(name: $0.name, status: .unknown) }
    }

    func collapsedView() -> AnyView? { nil }

    func expandedView() -> AnyView? {
        AnyView(CodeBridge(
            box: state,
            onAction:    { [weak self] index, action in self?.perform(action, at: index) },
            onRemove:    { [weak self] index in self?.remove(at: index) },
            onDrop:      { [weak self] urls in self?.pin(urls) },
            onLaunchCLI: { [weak self] tool in self?.launchCLI(tool) }
        ))
    }

    func dashboardTile() -> AnyView? {
        AnyView(CodeDashboardBridge(
            box: state,
            terminals: terminals,
            onAction:    { [weak self] index, action in self?.perform(action, at: index) },
            onRemove:    { [weak self] index in self?.remove(at: index) },
            onDrop:      { [weak self] urls in self?.pin(urls) },
            onLaunchCLI: { [weak self] tool in self?.launchCLI(tool) }
        ))
    }

    func wideBarView() -> AnyView? {
        AnyView(CodeWideBarBridge(box: state))
    }

    func activate() {
        startTimer()
        Task { @MainActor in await refresh() }
    }

    func deactivate() {
        timer?.invalidate()
        timer = nil
        refreshGeneration += 1
        refreshRequested = false
        terminals.values.forEach { $0.stop() }
    }

    func refresh() async {
        refreshRequested = true
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        while refreshRequested {
            refreshRequested = false
            let generation = refreshGeneration
            let projects = store.projects
            // Keep one display row per saved project, even when its bookmark is unavailable.
            let entries = projects.map { ($0.name, store.resolve($0)?.path) }
            let displays = await Task.detached(priority: .utility) {
                entries.map { name, path in
                    CodeProjectDisplay(name: name, status: path.map { GitProbe.status(atPath: $0) } ?? .unknown)
                }
            }.value
            guard generation == refreshGeneration else { continue }
            guard projects == store.projects else {
                refreshRequested = true
                continue
            }
            state.projects = displays
        }
    }

    private func pin(_ urls: [URL]) {
        let folders = urls.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        guard !folders.isEmpty else { return }
        folders.forEach { store.add($0) }
        synchronizeRows()
        Task { @MainActor in await refresh() }
    }

    private func remove(at index: Int) {
        guard store.projects.indices.contains(index) else { return }
        store.remove(at: index)
        synchronizeRows()
        Task { @MainActor in await refresh() }
    }

    private func synchronizeRows() {
        // Publish the new ordering synchronously so index-based actions always match the store.
        state.projects = store.projects.map { CodeProjectDisplay(name: $0.name, status: .unknown) }
    }

    private func perform(_ action: CodeAction, at index: Int) {
        guard store.projects.indices.contains(index),
              let url = store.resolve(store.projects[index]) else { return }
        Launcher.perform(action, path: url.path)
    }

    private func launchCLI(_ tool: CodeCLITool) {
        // Run inside the notch panel via PTY instead of opening a separate Terminal window.
        terminals[tool]?.launch(tool: tool)
    }

    private func startTimer() {
        guard timer == nil else { return }
        let interval = EnergyRefreshPolicy.interval(base: 30, lowPowerMultiplier: 4)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        timer?.tolerance = EnergyRefreshPolicy.tolerance(for: interval)
    }
}

// MARK: - Bridges (ObservableObject glue for SwiftUI)

private struct CodeBridge: View {
    @ObservedObject var box: CodeModule.StateBox
    let onAction: (Int, CodeAction) -> Void
    let onRemove: (Int) -> Void
    let onDrop: ([URL]) -> Void
    var onLaunchCLI: ((CodeCLITool) -> Void)? = nil

    var body: some View {
        CodeExpandedView(
            projects: box.projects,
            onAction: onAction,
            onRemove: onRemove,
            onDrop: onDrop,
            onLaunchCLI: onLaunchCLI
        )
    }
}

private struct CodeDashboardBridge: View {
    @ObservedObject var box: CodeModule.StateBox
    let terminals: [CodeCLITool: NotchTerminal]
    let onAction: (Int, CodeAction) -> Void
    let onRemove: (Int) -> Void
    let onDrop: ([URL]) -> Void
    let onLaunchCLI: (CodeCLITool) -> Void

    var body: some View {
        CodeDashboardTile(
            projects: box.projects,
            onAction: onAction,
            onRemove: onRemove,
            onDrop: onDrop,
            onLaunchCLI: onLaunchCLI,
            terminals: terminals
        )
    }
}

private struct CodeWideBarBridge: View {
    @ObservedObject var box: CodeModule.StateBox

    var body: some View {
        CodeWideBar(projects: box.projects)
    }
}
