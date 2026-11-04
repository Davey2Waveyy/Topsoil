import Foundation

public struct StockQuote: Equatable, Sendable {
    public var symbol: String
    public var price: Double
    public var previousClose: Double
    public var history: [Double]

    public init(symbol: String, price: Double, previousClose: Double, history: [Double]) {
        self.symbol = symbol
        self.price = price
        self.previousClose = previousClose
        self.history = history
    }

    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return (price - previousClose) / previousClose * 100
    }

    var isUp: Bool { changePercent >= 0 }
}

public enum StockTickerSelection {
    public static func normalized(_ symbol: String) -> String? {
        let clean = symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !clean.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        guard clean.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return clean
    }

    public static func add(_ symbol: String, to tickers: [String]) -> [String] {
        guard let clean = normalized(symbol),
              !tickers.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame })
        else { return tickers }
        return tickers + [clean]
    }

    public static func remove(at index: Int, from tickers: [String]) -> [String] {
        guard tickers.indices.contains(index) else { return tickers }
        var next = tickers
        next.remove(at: index)
        return next
    }
}

enum StocksFetcher {
    static func fetch(symbols: [String]) async -> [StockQuote] {
        await withTaskGroup(of: (Int, StockQuote?).self) { group in
            for (i, symbol) in symbols.enumerated() {
                group.addTask { (i, try? await fetchOne(symbol: symbol)) }
            }
            var pairs: [(Int, StockQuote)] = []
            for await (i, quote) in group {
                if let q = quote { pairs.append((i, q)) }
            }
            return pairs.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private static func fetchOne(symbol: String) async throws -> StockQuote {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=1mo") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try parse(data: data, symbol: symbol)
    }

    private static func parse(data: Data, symbol: String) throws -> StockQuote {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let chart = json["chart"] as? [String: Any],
            let results = chart["result"] as? [[String: Any]],
            let first = results.first
        else { throw URLError(.cannotParseResponse) }

        let meta = first["meta"] as? [String: Any] ?? [:]
        let price = meta["regularMarketPrice"] as? Double ?? 0
        let prevClose = meta["chartPreviousClose"] as? Double
            ?? meta["previousClose"] as? Double
            ?? 0

        let closes = ((first["indicators"] as? [String: Any])?["quote"] as? [[String: Any]])?
            .first?["close"] as? [Double?] ?? []

        return StockQuote(
            symbol: symbol,
            price: price,
            previousClose: prevClose,
            history: closes.compactMap { $0 }
        )
    }
}

/// Last successful content survives transient network failures, with explicit freshness.
public struct MarketSnapshot: Equatable, Sendable {
    public private(set) var quotes: [StockQuote] = []
    public private(set) var staleSymbols: Set<String> = []
    public private(set) var repos: [TrendingRepository] = []
    public private(set) var reposStale = false

    public init() {}

    public mutating func applyQuotes(_ incoming: [StockQuote], tickers: [String]) {
        let latest = Dictionary(incoming.map { ($0.symbol, $0) }, uniquingKeysWith: { _, last in last })
        let previous = Dictionary(quotes.map { ($0.symbol, $0) }, uniquingKeysWith: { _, last in last })
        quotes = tickers.compactMap { latest[$0] ?? previous[$0] }
        staleSymbols = Set(tickers.filter { latest[$0] == nil })
    }

    public mutating func selectTickers(_ tickers: [String]) {
        let selected = Set(tickers)
        quotes.removeAll { !selected.contains($0.symbol) }
        staleSymbols.formIntersection(selected)
    }

    public mutating func applyRepos(_ incoming: [TrendingRepository]?) {
        reposStale = incoming == nil
        if let incoming { repos = incoming }
    }
}
