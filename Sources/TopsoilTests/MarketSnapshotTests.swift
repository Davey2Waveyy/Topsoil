import Foundation
import TopsoilKit

func marketSnapshotTests() {
    test("markets: partial refresh preserves last good quotes and marks them stale") {
        var snapshot = MarketSnapshot()
        let apple = StockQuote(symbol: "AAPL", price: 100, previousClose: 99, history: [99, 100])
        let nvidia = StockQuote(symbol: "NVDA", price: 120, previousClose: 110, history: [110, 120])
        snapshot.applyQuotes([apple, nvidia], tickers: ["AAPL", "NVDA"])
        snapshot.applyQuotes([nvidia], tickers: ["AAPL", "NVDA"])
        expectEqual(snapshot.quotes, [apple, nvidia], "keeps last successful value in ticker order")
        expectEqual(snapshot.staleSymbols, ["AAPL"], "only failed quote is stale")
        snapshot.applyQuotes([], tickers: ["NVDA"])
        expectEqual(snapshot.quotes, [nvidia], "removed ticker cannot reappear")
        snapshot.applyQuotes([nvidia], tickers: ["NVDA"])
        expect(snapshot.staleSymbols.isEmpty, "successful retry clears stale status")
    }
    test("markets: repository failure differs from a successful empty result") {
        var snapshot = MarketSnapshot()
        let repo = TrendingRepository(fullName: "owner/repo", url: URL(string: "https://github.com/owner/repo")!, description: nil, stars: 2, language: nil)
        snapshot.applyRepos([repo])
        snapshot.applyRepos(nil)
        expectEqual(snapshot.repos, [repo], "failure retains repositories")
        expect(snapshot.reposStale, "failure is visible")
        snapshot.applyRepos([])
        expect(snapshot.repos.isEmpty, "valid empty response clears outdated results")
        expect(!snapshot.reposStale, "successful response clears stale status")
    }
}
