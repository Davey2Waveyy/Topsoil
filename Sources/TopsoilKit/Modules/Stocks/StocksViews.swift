import AppKit
import SwiftUI

struct StocksDashboardTile: View {
    @Environment(\.notchTokens) private var tokens
    let quotes: [StockQuote]
    let tickers: [String]
    let trendingRepos: [TrendingRepository]
    var staleSymbols: Set<String> = []
    var reposStale: Bool = false
    let installedSkills: [InstalledCodingSkill]
    let isFetching: Bool
    let isFetchingTrends: Bool
    let onAdd: (String) -> Void
    let onRemove: (Int) -> Void

    @State private var isEditing = false
    @State private var newTicker = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(alignment: .top, spacing: 16) {
                marketColumn
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                repoColumn
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                skillsColumn
                    .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tokens.accent)
            Text("MARKETS + CODE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.55))

            if !tickers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(tickers.enumerated()), id: \.offset) { index, ticker in
                            TickerSelectionChip(
                                symbol: ticker,
                                isEditing: isEditing,
                                onRemove: {
                                    withAnimation(tokens.panelAnimation) {
                                        onRemove(index)
                                    }
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: 130)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(tokens.panelAnimation) {
                    isEditing.toggle()
                    if isEditing { inputFocused = true }
                }
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isEditing ? tokens.accent : .white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .help(isEditing ? "Done" : "Add ticker")
        }
    }

    // MARK: - Market column

    @ViewBuilder
    private var marketColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("Stocks", systemImage: "chart.line.uptrend.xyaxis")
            if isEditing {
                addRow.transition(.move(edge: .top).combined(with: .opacity))
            }
            if !staleSymbols.isEmpty {
                Label(quotes.isEmpty ? "Quotes unavailable · retrying" : "Some quotes are out of date", systemImage: "clock.arrow.circlepath")
                    .font(tokens.captionFont)
                    .foregroundStyle(tokens.warning)
            }
            if isFetching && quotes.isEmpty {
                loadingRows
            } else if quotes.isEmpty {
                emptyLine(tickers.isEmpty ? "Tap + to add a ticker" : "Quotes unavailable")
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 5) {
                        ForEach(quotes, id: \.symbol) { quote in
                            VStack(alignment: .leading, spacing: 2) {
                                StockRow(quote: quote)
                                if staleSymbols.contains(quote.symbol) {
                                    Text("Last available quote").font(tokens.captionFont).foregroundStyle(tokens.warning)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Repo column

    private var repoColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("Repos today", systemImage: "star")
            if reposStale {
                Label(trendingRepos.isEmpty ? "GitHub unavailable · retrying" : "Showing last available repos", systemImage: "clock.arrow.circlepath")
                    .font(tokens.captionFont)
                    .foregroundStyle(tokens.warning)
            }
            if isFetchingTrends && trendingRepos.isEmpty {
                loadingRows
            } else if trendingRepos.isEmpty {
                emptyLine("No repo trends yet")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(trendingRepos) { repo in
                            RepoTrendRow(repo: repo)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Skills column

    private var skillsColumn: some View {
        let trailing: String? = installedSkills.isEmpty ? nil : "\(installedSkills.count)"
        return VStack(alignment: .leading, spacing: 7) {
            sectionLabel("Skills", systemImage: "puzzlepiece.extension", trailing: trailing)
            if installedSkills.isEmpty {
                emptyLine("No skills found")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    SkillsListView(skills: InstalledSkillPresentation.displayItems(from: installedSkills))
                }
            }
        }
    }

    // MARK: - Shared helpers

    private func sectionLabel(_ title: String, systemImage: String, trailing: String? = nil) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tokens.accent.opacity(0.85))
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
    }

    private var loadingRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.08))
                    .frame(height: 32)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.28))
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Add ticker row

    private var addRow: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(tokens.accent.opacity(0.70))
            TextField("TSLA, BRK.B", text: $newTicker)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onSubmit { submitTicker() }
            Button { submitTicker() } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(newTicker.isEmpty ? .white.opacity(0.15) : tokens.accent)
            }
            .buttonStyle(.plain)
            .disabled(StockTickerSelection.normalized(newTicker) == nil)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(tokens.accent.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private func submitTicker() {
        guard StockTickerSelection.normalized(newTicker) != nil else { return }
        onAdd(newTicker)
        newTicker = ""
    }
}

// MARK: - Ticker chip

private struct TickerSelectionChip: View {
    @Environment(\.notchTokens) private var tokens
    let symbol: String
    let isEditing: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.70))
            if isEditing {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.38))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, isEditing ? 4 : 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(isEditing ? 0.072 : 0.044))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white.opacity(isEditing ? 0.12 : 0.06), lineWidth: 0.6)
                )
        )
        .animation(tokens.panelAnimation, value: isEditing)
    }
}

// MARK: - Repo row

private struct RepoTrendRow: View {
    @Environment(\.notchTokens) private var tokens
    let repo: TrendingRepository
    @State private var isHovered = false

    private var starLabel: String {
        repo.stars >= 1_000
            ? String(format: "%.1fk", Double(repo.stars) / 1_000)
            : "\(repo.stars)"
    }

    var body: some View {
        Button { NSWorkspace.shared.open(repo.url) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(repo.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(isHovered ? 1 : 0.90))
                        .lineLimit(1)
                    if let desc = repo.description?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(tokens.accent.opacity(0.80))
                        Text(starLabel)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(tokens.accent)
                    }
                    if let lang = repo.language, !lang.isEmpty {
                        Text(lang)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.075 : 0.048))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(isHovered ? 0.13 : 0.07), lineWidth: 0.7)
                    )
            )
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(repo.fullName) on GitHub")
    }
}

// MARK: - Skill rows

private struct SkillsListView: View {
    let skills: [InstalledCodingSkill]

    private var grouped: [(tool: CodeCLITool, skills: [InstalledCodingSkill])] {
        var map: [CodeCLITool: [InstalledCodingSkill]] = [:]
        for s in skills { map[s.cli, default: []].append(s) }
        return CodeCLITool.allCases.compactMap { tool in
            guard let group = map[tool], !group.isEmpty else { return nil }
            return (tool, group)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(grouped, id: \.tool) { group in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        CodeToolIcon(tool: group.tool, size: 10)
                            .frame(width: 12)
                        Text(group.tool.displayName.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                    VStack(spacing: 3) {
                        ForEach(group.skills, id: \.id) { skill in
                            SkillChip(name: skill.name)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SkillChip: View {
    let name: String
    @State private var isHovered = false

    var body: some View {
        Text(name)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(isHovered ? 0.90 : 0.70))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.068 : 0.038))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(isHovered ? 0.11 : 0.06), lineWidth: 0.6)
                    )
            )
            .animation(.easeOut(duration: 0.10), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Stock row

struct StockRow: View {
    let quote: StockQuote

    private var trendColor: Color {
        quote.isUp
            ? Color(red: 0.33, green: 0.82, blue: 0.52)
            : Color(red: 0.92, green: 0.37, blue: 0.37)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(quote.symbol)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 48, alignment: .leading)
            SparklineView(values: quote.history, color: trendColor)
                .frame(height: 22)
                .frame(maxWidth: .infinity)
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "$%.2f", quote.price))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                let pct = quote.changePercent
                Text(String(format: "%@%.2f%%", pct >= 0 ? "+" : "", pct))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(trendColor)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if values.count >= 2,
               let minV = values.min(),
               let maxV = values.max() {
                let range = maxV == minV ? 1.0 : maxV - minV
                let pts: [CGPoint] = values.enumerated().map { i, v in
                    CGPoint(
                        x: CGFloat(i) / CGFloat(values.count - 1) * w,
                        y: h - (CGFloat((v - minV) / range) * (h - 4) + 2)
                    )
                }
                Path { p in
                    p.move(to: pts[0])
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
