// apps/example_ios/example_ios/MockDataSource.swift
//
// Reads the shared fixture (bundled as Resources/{symbols,oi,orders,
// positions,oco_orders}.json, symlinked from apps/mock/) and serves it as
// plain reads, plus this platform's own native live-tick and candle-walk
// generation widened to every symbol in the fixture.
import Foundation

final class MockDataSource {

    private let fixture: [String: Any]
    private let niftySymbol: [String: Any]
    private let optionChain: [[String: Any]]
    private let futureSymbolsArray: [[String: Any]]
    private let basePrices: [String: Double]

    private var livePrices: [String: Double] = [:]

    init() {
        var json: [String: Any] = [:]
        for name in ["symbols", "oi", "orders", "positions", "oco_orders"] {
            guard
                let url = Bundle.main.url(forResource: name, withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let part = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                fatalError("\(name).json is missing from the app bundle or failed to parse")
            }
            json.merge(part) { _, new in new }
        }

        let requiredKeys = [
            "niftySymbol", "optionChain", "futureSymbols", "indexSymbols",
            "basePrices", "topOptionsByVolume", "oi", "pcrIntraday",
            "atmStraddleIntraday", "atmIvIntraday", "seedOrders",
            "seedPositions", "seedOcoOrders",
        ]
        for key in requiredKeys {
            guard json[key] != nil else {
                fatalError("mock fixture is missing required key: \(key)")
            }
        }

        fixture = json
        niftySymbol = json["niftySymbol"] as! [String: Any]
        optionChain = json["optionChain"] as! [[String: Any]]
        futureSymbolsArray = json["futureSymbols"] as! [[String: Any]]
        basePrices = (json["basePrices"] as! [String: Any]).mapValues { ($0 as? Double) ?? 22600.0 }
    }

    private func priceFor(_ symbolId: String) -> Double {
        if let existing = livePrices[symbolId] { return existing }
        let base = basePrices[symbolId] ?? 22600.0
        livePrices[symbolId] = base
        return base
    }

    private func toJson(_ object: Any) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(data: data, encoding: .utf8)!
    }

    // -------------------------------------------------------------------
    // Static fixture reads
    // -------------------------------------------------------------------

    func symbolInfo() -> String { toJson(niftySymbol) }

    /// Exchange calendar. `sessions` is an array indexed by weekday
    /// (0 = Monday ... 6 = Sunday), each entry an array of "HHMM-HHMM" ranges
    /// and an empty array for a non-trading day -- see `MarketTiming.fromJson`
    /// in lib/src/models/market_timing.dart.
    // Open every hour of every day -- a real exchange trades ~6h on weekdays
    // only, but this is a demo: it should show live movement no matter when
    // someone runs it, not just 09:15-15:30 IST on a weekday.
    func marketTiming() -> String {
        let sessions: [[String]] = (0 ..< 7).map { _ in ["0000-2359"] }
        return toJson([
            "timezone": "Asia/Kolkata",
            "sessions": sessions,
            "holidays": [],
            "special": [:],
        ])
    }

    func futureSymbols() -> String { toJson(futureSymbolsArray) }
    func indexSymbols() -> String { toJson(fixture["indexSymbols"]!) }
    /// The bare option chain -- `MKTDataInterface.optionSymbols`' contract.
    func optionSymbols() -> String { toJson(optionChain) }

    /// The option chain with the underlying's own symbol info prepended.
    /// `MKTDataInterface.fetchOptionDetails` requires the first element to be
    /// the spot symbol (the one entry without an "optType") so the chart can
    /// resolve the spot price.
    func fetchOptionDetails() -> String { toJson([niftySymbol] + optionChain) }
    func chartTopOptions() -> String { toJson(fixture["topOptionsByVolume"]!) }

    func fetchOI() -> String {
        toJson((fixture["oi"] as! [String: Any])["byStrike"]!)
    }
    func fetchOIChange() -> String {
        toJson((fixture["oi"] as! [String: Any])["changeByStrike"]!)
    }
    func fetchOIAnalysis() -> String {
        toJson((fixture["oi"] as! [String: Any])["analysisAroundAtm"]!)
    }

    func fetchPcrIntraday() -> String {
        toJson(withResolvedTimes(fixture["pcrIntraday"] as! [[String: Any]]))
    }
    func fetchAtmIvIntraday() -> String {
        toJson(withResolvedTimes(fixture["atmIvIntraday"] as! [[String: Any]]))
    }

    func fetchAtmStraddleIntraday() -> String {
        let source = fixture["atmStraddleIntraday"] as! [String: Any]
        var resolved: [String: Any] = [:]
        for (expiry, rows) in source {
            resolved[expiry] = withResolvedTimes(rows as! [[String: Any]])
        }
        return toJson(resolved)
    }

    /// Rewrites each row's "offsetMinutes" into an absolute "time" (ms epoch) so the series always looks live relative to now.
    ///
    /// Read through `NSNumber` rather than `as? Int`: `JSONSerialization`
    /// hands back whichever numeric representation the JSON literal used, so a
    /// regenerated fixture emitting `240.0` instead of `240` would fail a
    /// direct `Int` cast and silently resolve to "now".
    private func withResolvedTimes(_ rows: [[String: Any]]) -> [[String: Any]] {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return rows.map { row in
            var resolved = row
            let offsetMinutes = (row["offsetMinutes"] as? NSNumber)?.int64Value ?? 0
            resolved.removeValue(forKey: "offsetMinutes")
            resolved["time"] = now - offsetMinutes * 60_000
            return resolved
        }
    }

    func seedOrders() -> String {
        let rows = withSymbolAttached(fixture["seedOrders"] as! [[String: Any]])
        let resolved = rows.map { row -> [String: Any] in
            var resolved = row
            // NSNumber, not `as? Int` -- see withResolvedTimes' note.
            if let offsetMinutes = (resolved["ordTimeOffsetMinutes"] as? NSNumber)?.intValue {
                resolved.removeValue(forKey: "ordTimeOffsetMinutes")
                resolved["ordTime"] = formatOrdTime(offsetMinutes: offsetMinutes)
            }
            return resolved
        }
        return toJson(resolved)
    }
    func seedPositions() -> String {
        toJson(withSymbolAttached(fixture["seedPositions"] as! [[String: Any]]))
    }
    // No seedOcoOrders() reader: this host reports hasOCO = false and doesn't
    // implement place/modify/cancelOCOOrder, so seeding an OCO marker the user
    // could drag would only surface a not-implemented failure.

    private func withSymbolAttached(_ rows: [[String: Any]]) -> [[String: Any]] {
        rows.map { row in
            var withSymbol = row
            withSymbol["symbol"] = niftySymbol
            return withSymbol
        }
    }

    /// Resolves an "ordTimeOffsetMinutes" fixture field into the
    /// "dd-MM-yyyy HH:mm:ss" string order consumers expect for "ordTime"
    /// (see TradeInterface.ordersStreamer doc / StringX.formatTime parser).
    private static let ordTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func formatOrdTime(offsetMinutes: Int) -> String {
        let date = Date().addingTimeInterval(-Double(offsetMinutes) * 60)
        return Self.ordTimeFormatter.string(from: date)
    }

    // -------------------------------------------------------------------
    // Native live generation, widened to every fixture symbol
    // -------------------------------------------------------------------

    func generateOhlcv(symbolId: String, intervalSeconds: Int, barCount: Int) -> String {
        let interval = TimeInterval(intervalSeconds)
        let endTime = Date().timeIntervalSince1970
        var bars: [[Any]] = []
        var price = priceFor(symbolId)

        for i in stride(from: barCount - 1, through: 0, by: -1) {
            let ts = Int64((endTime - Double(i) * interval) * 1000)
            let open = price
            let change = (Double.random(in: 0 ..< 1) - 0.48) * (open * 0.002)
            let close = max(1.0, open + change)
            let high = max(open, close) + Double.random(in: 0 ..< (open * 0.001))
            let low = max(0.5, min(open, close) - Double.random(in: 0 ..< (open * 0.001)))
            let volume = Double(Int.random(in: 1000 ..< 6000))
            bars.append([ts, open, high, low, close, volume])
            price = close
        }
        livePrices[symbolId] = price
        return toJson(bars)
    }

    /// One tick per symbol: spot, then every option, then every future -- matching MockChartDataSource.generateTicks()'s breadth.
    func nextTicks() -> String {
        var ticks: [[String: Any]] = []
        ticks.append(tickFor(niftySymbol["id"] as! String))
        for option in optionChain {
            ticks.append(tickFor(option["id"] as! String))
        }
        for future in futureSymbolsArray {
            ticks.append(tickFor(future["id"] as! String))
        }
        return toJson(ticks)
    }

    private func tickFor(_ symbolId: String) -> [String: Any] {
        let base = basePrices[symbolId] ?? 22600.0
        var price = priceFor(symbolId)
        price += (Double.random(in: 0 ..< 1) - 0.48) * (base * 0.001)
        price = max(0.05, price)
        livePrices[symbolId] = price
        let ltp = (price * 100).rounded() / 100
        return [
            "symbolId": symbolId,
            "ltp": ltp,
            "ltq": Int.random(in: 10 ..< 60),
            "chng": ((ltp - base) * 100).rounded() / 100,
            "chngPer": (((ltp - base) / base) * 10000).rounded() / 100,
            "ltt": Int64(Date().timeIntervalSince1970 * 1000),
        ]
    }
}
