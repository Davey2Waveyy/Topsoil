import AppKit
import SwiftUI

@MainActor
final class ClipboardModule: NotchModule {
    let id = "clipboard"
    let title = "Clipboard"
    var isEnabled = true

    final class StateBox: ObservableObject {
        @Published var entries: [ClipboardEntry] = []
    }

    private let state = StateBox()
    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount: Int = -1

    init() {
        self.store = ClipboardStore(url: ClipboardStore.defaultURL())
        state.entries = store.entries
    }

    func collapsedView() -> AnyView? {
        AnyView(ClipboardCollapsedBridge(box: state))
    }

    func expandedView() -> AnyView? { nil }

    func dashboardTile() -> AnyView? {
        AnyView(ClipboardDashboardBridge(
            box: state,
            onRemove: { [weak self] id in self?.remove(id: id) },
            onCopy: { [weak self] text in self?.copyToPasteboard(text) }
        ))
    }

    func wideBarView() -> AnyView? {
        AnyView(ClipboardWideBarBridge(box: state))
    }

    func activate() {
        guard timer == nil else { return }
        // Sync the baseline change count so we only track NEW copies from here on.
        lastChangeCount = NSPasteboard.general.changeCount
        state.entries = store.entries
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
        timer?.tolerance = EnergyRefreshPolicy.tolerance(for: 5)
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func deactivate() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async { poll() }

    // MARK: - Private

    private func poll() {
        let board = NSPasteboard.general
        let current = board.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let text = board.string(forType: .string) else { return }
        if store.add(text) {
            state.entries = store.entries
        }
    }

    private func remove(id: UUID) {
        store.remove(id: id)
        state.entries = store.entries
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
    }
}

private struct ClipboardCollapsedBridge: View {
    @ObservedObject var box: ClipboardModule.StateBox
    var body: some View {
        if !box.entries.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(box.entries.count)")
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

private struct ClipboardDashboardBridge: View {
    @ObservedObject var box: ClipboardModule.StateBox
    let onRemove: (UUID) -> Void
    let onCopy: (String) -> Void

    var body: some View {
        ClipboardDashboardTile(entries: box.entries, onRemove: onRemove, onCopy: onCopy)
    }
}

private struct ClipboardWideBarBridge: View {
    @ObservedObject var box: ClipboardModule.StateBox
    var body: some View {
        WideBarItem(systemImage: "doc.on.clipboard", text: "\(box.entries.count)")
    }
}
