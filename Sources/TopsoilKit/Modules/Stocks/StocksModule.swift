import SwiftUI

@MainActor
final class StocksModule: NotchModule {
    let id = "stocks"
    let title = "Stocks"
    var isEnabled = true
    var isFullPageTile: Bool { true }

    private static let defaultTickers = ["AAPL", "NVDA", "MSFT"]
    private static let tickersKey = "io.local.macnotch.stockTickers"

    final class StateBox: ObservableObject {
        @Published var tickers: [String] = []
        @Published var snapshot = MarketSnapshot()
        @Published var installedSkills: [InstalledCodingSkill] = []
        @Published var isFetching = false
        @Published var isFetchingTrends = false
    }

    private let state = StateBox()
    private var tickers: [String]
    private var timer: Timer?
    private var refreshPending = false
    private var lastDiscoveryRefresh: Date?
    private var lastRepoRefresh: Date?


    init() {
        tickers = UserDefaults.standard.stringArray(forKey: Self.tickersKey) ?? Self.defaultTickers
        state.tickers = tickers
    }

    func collapsedView() -> AnyView? { nil }
    func expandedView() -> AnyView? { nil }

    func dashboardTile() -> AnyView? {
        AnyView(StocksBridge(
            box: state,
            onAdd: { [weak self] sym in self?.addTicker(sym) },
            onRemove: { [weak self] idx in self?.removeTicker(at: idx) }
        ))
    }

    func wideBarView() -> AnyView? { nil }

    func activate() {
        startTimer()
        Task { @MainActor in await refresh() }
    }

    func deactivate() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        guard !state.isFetching else {
            refreshPending = true
            return
        }
        state.isFetching = true
        defer { state.isFetching = false }

        repeat {
            refreshPending = false
            let requested = tickers
            let now = Date()
            let updateRepos = lastRepoRefresh.map { now.timeIntervalSince($0) >= 600 } ?? true
            let updateSkills = lastDiscoveryRefresh.map { now.timeIntervalSince($0) >= 300 } ?? true
            state.isFetchingTrends = updateRepos

            async let quotes = StocksFetcher.fetch(symbols: requested)
            async let repos = updateRepos ? fetchTrendingRepos() : nil
            let skillsTask = updateSkills ? Task.detached(priority: .utility) { CodingSkillDiscovery.discover() } : nil

            let incomingQuotes = await quotes
            // A ticker edit can occur while the request is suspended.
            if requested == tickers {
                var next = state.snapshot
                next.applyQuotes(incomingQuotes, tickers: tickers)
                if next != state.snapshot { state.snapshot = next }
            } else {
                refreshPending = true
            }
            if updateRepos {
                let incomingRepos = await repos
                var next = state.snapshot
                next.applyRepos(incomingRepos)
                if next != state.snapshot { state.snapshot = next }
                if incomingRepos != nil { lastRepoRefresh = now }
            }
            if let skillsTask {
                let skills = await skillsTask.value
                if skills != state.installedSkills { state.installedSkills = skills }
                lastDiscoveryRefresh = now
            }
            state.isFetchingTrends = false
        } while refreshPending
    }

    func addTicker(_ symbol: String) {
        let next = StockTickerSelection.add(symbol, to: tickers)
        guard next != tickers else { return }
        setTickers(next)
        Task { @MainActor in await refresh() }
    }

    func removeTicker(at index: Int) {
        let next = StockTickerSelection.remove(at: index, from: tickers)
        guard next != tickers else { return }
        setTickers(next)
        state.snapshot.selectTickers(next)
    }

    private func setTickers(_ next: [String]) {
        tickers = next
        state.tickers = next
        UserDefaults.standard.set(next, forKey: Self.tickersKey)
    }

    private func fetchTrendingRepos() async -> [TrendingRepository]? {
        let since = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let url = GitHubTrendingRequest.url(since: since, limit: 5)
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(NotchBrand.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try GitHubTrendingParser.parse(data)
        } catch {
            return nil
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        let interval = EnergyRefreshPolicy.interval(base: 60, lowPowerMultiplier: 5)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        timer?.tolerance = EnergyRefreshPolicy.tolerance(for: interval)
    }
}

private struct StocksBridge: View {
    @ObservedObject var box: StocksModule.StateBox
    let onAdd: (String) -> Void
    let onRemove: (Int) -> Void

    var body: some View {
        StocksDashboardTile(
            quotes: box.snapshot.quotes,
            tickers: box.tickers,
            trendingRepos: box.snapshot.repos,
            staleSymbols: box.snapshot.staleSymbols,
            reposStale: box.snapshot.reposStale,
            installedSkills: box.installedSkills,
            isFetching: box.isFetching,
            isFetchingTrends: box.isFetchingTrends,
            onAdd: onAdd,
            onRemove: onRemove
        )
    }
}
