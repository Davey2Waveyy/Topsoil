import AppKit
import SwiftUI

// MARK: - Model

struct CodeProjectDisplay: Equatable, Sendable {
    var name: String
    var status: GitStatus
}

private func accent(for tool: CodeCLITool) -> Color {
    switch tool {
    case .claude: return Color(red: 0.78, green: 0.52, blue: 1.00)
    case .codex: return Color(red: 0.36, green: 0.78, blue: 1.00)
    case .cursor: return Color(red: 0.27, green: 0.98, blue: 0.72)
    }
}

// MARK: - Compact expanded view

struct CodeExpandedView: View {
    let projects: [CodeProjectDisplay]
    let onAction: (Int, CodeAction) -> Void
    let onRemove: (Int) -> Void
    let onDrop: ([URL]) -> Void
    var onLaunchCLI: ((CodeCLITool) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CODE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.40))
                .frame(maxWidth: .infinity, alignment: .leading)

            if projects.isEmpty {
                emptyProject
                cliQuickLaunch
            } else {
                ForEach(projects.indices, id: \.self) { index in
                    row(projects[index], index: index)
                }
                cliQuickLaunch
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .urlDropTarget(onDrop)
    }

    // Always-visible CLI quick-launch row so the tile is never empty.
    @ViewBuilder
    private var cliQuickLaunch: some View {
        HStack(spacing: 6) {
            ForEach(CodeTerminalPaneDescriptor.defaultPanes) { pane in
                cliChip(pane)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Light, text-first chip: a tinted tool dot + command, no boxed border.
    private func cliChip(_ pane: CodeTerminalPaneDescriptor) -> some View {
        Button { onLaunchCLI?(pane.tool) } label: {
            HStack(spacing: 5) {
                CodeToolIcon(tool: pane.tool, size: 12)
                Text(pane.command)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .help("Open \(pane.displayName) in notch")
    }

    private var emptyProject: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("No folder pinned")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
            Text("drop a folder")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func row(_ project: CodeProjectDisplay, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                statusLine(project.status)
            }

            HStack(spacing: 16) {
                actionButton("sparkles", help: "Launch Claude Code") { onAction(index, .claudeCode) }
                actionButton("chevron.left.forwardslash.chevron.right", help: "Open in editor") { onAction(index, .editor) }
                actionButton("terminal", help: "Open Terminal") { onAction(index, .terminal) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contextMenu {
            Button("Reveal in Finder") { onAction(index, .reveal) }
            Button("Remove", role: .destructive) { onRemove(index) }
        }
    }

    @ViewBuilder
    private func statusLine(_ status: GitStatus) -> some View {
        HStack(spacing: 5) {
            if let branch = status.branch {
                Text(branch)
                    .foregroundStyle(.white.opacity(0.6))
                if status.isDirty {
                    Circle().fill(Color(red: 1, green: 0.72, blue: 0.2)).frame(width: 5, height: 5)
                }
                if status.ahead > 0 {
                    Text("↑\(status.ahead)").foregroundStyle(.white.opacity(0.5))
                }
                if status.behind > 0 {
                    Text("↓\(status.behind)").foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Text("no repo").foregroundStyle(.white.opacity(0.35))
            }
        }
        .font(.system(size: 9))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        NotchIconButton(systemName: systemName, accessibilityLabel: help,
                        size: 22, iconSize: 11, action: action)
    }
}

// MARK: - Embedded SwiftTerm terminal (NSViewRepresentable)

/// Hosts a session's persistent `LocalProcessTerminalView`. SwiftTerm handles all
/// keyboard input, scrolling, and rendering; we only manage focus so keystrokes
/// reach the right pane in the menu-bar panel.
private struct EmbeddedTerminalView: NSViewRepresentable {
    let terminal: NotchTerminal
    let isFocused: Bool
    let onFocus: () -> Void
    @Environment(\.notchTokens) private var tokens

    final class Coordinator {
        var isFocused = false
        var focusRequest: DispatchWorkItem?
        weak var terminal: NotchTerminal?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.terminal = terminal
        return terminal.terminalView
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.focusRequest?.cancel()
        coordinator.terminal?.onFocus = nil
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Caret + selection follow the app's live accent so the terminal matches
        // whatever theme colour the notch is using.
        terminal.applyAccent(NSColor(tokens.accent))
        terminal.onFocus = onFocus

        let coordinator = context.coordinator
        guard coordinator.isFocused != isFocused else { return }
        coordinator.isFocused = isFocused
        coordinator.focusRequest?.cancel()
        guard isFocused else { return }
        let request = DispatchWorkItem { [weak nsView, weak coordinator] in
            guard coordinator?.isFocused == true, let nsView, let window = nsView.window else { return }
            if !window.isKeyWindow { window.makeKey() }
            if window.firstResponder !== nsView { window.makeFirstResponder(nsView) }
        }
        coordinator.focusRequest = request
        DispatchQueue.main.async(execute: request)
    }
}

// MARK: - Split terminal panes

private struct SplitTerminalPane: View {
    @Environment(\.notchTokens) private var tokens
    let descriptor: CodeTerminalPaneDescriptor
    @ObservedObject var terminal: NotchTerminal
    let isFocused: Bool
    let onFocus: () -> Void
    let onLaunch: () -> Void
    let onStop: () -> Void

    private var accentColor: Color { accent(for: descriptor.tool) }

    var body: some View {
        VStack(spacing: 0) {
            titleBar.onTapGesture { onFocus(); terminal.focus() }
            if terminal.activeCLI == nil {
                idleBody.onTapGesture(perform: onFocus)
            } else {
                EmbeddedTerminalView(terminal: terminal, isFocused: isFocused, onFocus: onFocus)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .help("Scroll to review earlier output. Full-screen agents manage their own history.")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isFocused ? 0.055 : 0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isFocused ? tokens.accent.opacity(0.5) : Color.white.opacity(0.10), lineWidth: 0.7)
                )
        )
        .contentShape(Rectangle())
    }

    private var titleBar: some View {
        HStack(spacing: 7) {
            CodeToolIcon(tool: descriptor.tool, size: 14)

            VStack(alignment: .leading, spacing: 0) {
                Text(descriptor.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                Text(terminal.activeCLI == nil ? "Ready" : (terminal.isRunning ? "Running" : "Session ended"))
                    .font(tokens.captionFont)
                    .foregroundStyle(tokens.textSecondary)
            }

            Spacer(minLength: 4)

            if terminal.activeCLI == nil {
                Button(action: onLaunch) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start \(descriptor.displayName)")
                .help("Run \(descriptor.displayName)")
            } else {
                Button(action: terminal.scrollToLatest) {
                    Image(systemName: "arrow.down.to.line")
                        .foregroundStyle(tokens.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scroll \(descriptor.displayName) to latest output")
                .help("Latest output")

                Button(action: onStop) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(descriptor.displayName)")
                .help("Close \(descriptor.displayName)")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(isFocused ? 0.055 : 0.025))
    }

    private var idleBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(accentColor.opacity(0.70))
            Button(action: onLaunch) {
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .semibold))
                    Text("Start session")
                        .font(tokens.labelFont)
                }
                .foregroundStyle(.black.opacity(0.78))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accentColor.opacity(0.88))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Dashboard tile: full-width split CLI workspace

struct CodeDashboardTile: View {
    @Environment(\.notchTokens) private var tokens
    let projects: [CodeProjectDisplay]
    let onAction: (Int, CodeAction) -> Void
    let onRemove: (Int) -> Void
    let onDrop: ([URL]) -> Void
    let onLaunchCLI: (CodeCLITool) -> Void
    let terminals: [CodeCLITool: NotchTerminal]

    @State private var focusedTool: CodeCLITool = .claude
    @AppStorage("notch_garden_minimized") private var isGardenMinimized: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            workspaceHeader

            HStack(alignment: .top, spacing: 10) {
                ForEach(CodeTerminalPaneDescriptor.defaultPanes) { descriptor in
                    if let terminal = terminals[descriptor.tool] {
                        SplitTerminalPane(
                            descriptor: descriptor,
                            terminal: terminal,
                            isFocused: focusedTool == descriptor.tool,
                            onFocus: { focusedTool = descriptor.tool },
                            onLaunch: {
                                focusedTool = descriptor.tool
                                onLaunchCLI(descriptor.tool)
                            },
                            onStop: { terminal.stop() }
                        )
                    }
                }

                if isGardenMinimized {
                    Button(action: {
                        withAnimation(.smooth(duration: 0.25)) {
                            isGardenMinimized = false
                        }
                    }) {
                        VStack {
                            Spacer()
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(red: 0.22, green: 0.84, blue: 0.36))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.04))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.75))
                            Spacer()
                        }
                        .frame(width: 44, height: 110)
                        .background(Color.white.opacity(0.01))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help("Expand Garden")
                } else {
                    GardenDashboardWidget(isMinimized: $isGardenMinimized)
                        .frame(width: 240)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, projects.first == nil ? 8 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let proj = projects.first {
                projectFooter(proj)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .urlDropTarget(onDrop)
    }

    private var workspaceHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tokens.accent.opacity(0.86))
                .frame(width: 14)
            Text("Workspace")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
            Spacer(minLength: 8)
            Text(CodeTerminalPaneDescriptor.defaultPanes.map(\.executableName).joined(separator: " / "))
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.28))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.028))
    }

    private func projectFooter(_ proj: CodeProjectDisplay) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.22))
            Text("~/\(proj.name)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.28))
            if let branch = proj.status.branch {
                Text("·").foregroundStyle(.white.opacity(0.18))
                Text(branch)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.28))
                if proj.status.isDirty {
                    Circle().fill(Color(red: 1, green: 0.72, blue: 0.2)).frame(width: 4, height: 4)
                }
                if proj.status.ahead > 0 {
                    Text("↑\(proj.status.ahead)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.22))
                }
            }
            Spacer()
            Text("drop to pin")
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.15))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.03))
    }
}

// MARK: - Wide bar

struct CodeWideBar: View {
    let projects: [CodeProjectDisplay]

    var body: some View {
        if let first = projects.first {
            WideBarItem(systemImage: "chevron.left.forwardslash.chevron.right",
                        text: first.status.branch.map { "\(first.name) · \($0)" } ?? first.name) {
                if first.status.isDirty {
                    Circle().fill(Color(red: 1, green: 0.72, blue: 0.2)).frame(width: 5, height: 5)
                }
            }
        }
    }
}
