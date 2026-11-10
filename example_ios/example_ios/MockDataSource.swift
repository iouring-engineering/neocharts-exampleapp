// apps/example_ios/example_ios/MockDataSource.swift
//
// Reads the shared fixture (bundled as Resources/{symbols,oi,orders,
// positions,oco_orders,session}.json, symlinked from apps/mock/) and serves
// per-id reads, plus this platform's own candle and tick generation.
// Mirrors the Android example's MockDataSource.kt.
import Foundation

typealias Row = [String: Any]

/// Thin JSONSerialization helpers: objects are `[String: Any]`, arrays
/// `[Any]`, JSON null `NSNull`.
enum JSON {
    struct Invalid: Error, CustomStringConvertible {
        let description: String
    }

    /// Throws instead of letting JSONSerialization raise an ObjC exception.
    static func string(_ value: Any) throws -> String {
        guard JSONSerialization.isValidJSONObject([value]) else {
            throw Invalid(description: "not encodable as JSON: \(value)")
        }
        let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
        return String(decoding: data, as: UTF8.self)
    }

    static func object(_ text: String) throws -> Row {
        guard let row = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? Row else {
            throw Invalid(description: "expected a JSON object")
        }
        return row
    }
}

/// A number from a JSON or channel value (number or numeric string), else 0.
func number(_ value: Any?) -> Double {
    switch value {
    case let n as NSNumber: return n.doubleValue
    case let s as String: return Double(s) ?? 0
    default: return 0
    }
}

/// A clamped Int from a wire value: non-finite or huge numbers become 0, not a crash.
func int(_ value: Any?) -> Int {
    let d = number(value)
    guard d.isFinite, abs(d) < 1e15 else { return 0 }
    return Int(d)
}

extension Dictionary where Key == String, Value == Any {
    /// A required string value, else a thrown `JSON.Invalid`.
    func requireString(_ key: String) throws -> String {
        guard let value = self[key] as? String else { throw JSON.Invalid(description: "missing \(key)") }
        return value
    }
}

func round2(_ value: Double) -> Double { (value * 100).rounded() / 100 }

func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

final class MockDataSource {

    private let symbols: Row
    private let analytics: Row
    private let sessionFixture: Row
    private let seeds: Row

    private let optionRows: [Row]
    private let futureRows: [Row]
    private let indexRows: [Row]
    private let equityRows: [Row]
    private let basePrices: Row
    private let byId: [String: Row]

    init() {
        func load(_ name: String) -> Row {
            guard
                let url = Bundle.main.url(forResource: name, withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let row = try? JSONSerialization.jsonObject(with: data) as? Row
            else {
                fatalError("\(name).json is missing from the app bundle or failed to parse")
            }
            return row
        }
        symbols = load("symbols")
        analytics = load("oi")
        sessionFixture = load("session")
        seeds = ["orders", "positions", "oco_orders"].reduce(into: Row()) { acc, name in
            acc.merge(load(name)) { _, new in new }
        }

        let required = [
            "optionChain", "futureSymbols", "indexSymbols", "equitySymbols",
            "basePrices", "topOptionsByUnderlying",
        ]
        for key in required where symbols[key] == nil {
            fatalError("symbols.json is missing \(key)")
        }
        for key in ["seedOrders", "seedPositions", "seedOcoOrders"] where seeds[key] == nil {
            fatalError("mock fixture is missing \(key)")
        }

        optionRows = symbols["optionChain"] as! [Row]
        futureRows = symbols["futureSymbols"] as! [Row]
        indexRows = symbols["indexSymbols"] as! [Row]
        equityRows = symbols["equitySymbols"] as! [Row]
        basePrices = symbols["basePrices"] as! Row
        byId = (optionRows + futureRows + equityRows + indexRows).reduce(into: [:]) { map, row in
            map[row["id"] as! String] = row
        }
    }

    private func basePrice(_ id: String) -> Double {
        (basePrices[id] as? NSNumber)?.doubleValue ?? 22600.0
    }

    // -------------------------------------------------------------------
    // Session and symbol reads
    // -------------------------------------------------------------------

    /// session.json with `initialSymbolId` resolved into `initialSymbol`, plus
    /// the index symbols.
    func session() -> Row {
        let initialId = sessionFixture["initialSymbolId"] as! String
        guard let initial = symbol(initialId) else {
            fatalError("session.json: unknown initialSymbolId \(initialId)")
        }
        var session = sessionFixture
        session.removeValue(forKey: "initialSymbolId")
        session["initialSymbol"] = initial
        session["indexSymbols"] = indexRows
        return session
    }

    func symbol(_ id: String) -> Row? { byId[id] }

    /// Total: an underlying (or an unknown id) resolves to itself.
    func underlyingOf(_ symbolId: String) -> Row {
        guard let symbol = byId[symbolId] else { return ["id": symbolId] }
        guard let undId = symbol["undID"] as? String else { return symbol }
        return (indexRows + equityRows).first { $0["id"] as? String == undId } ?? symbol
    }

    func optionChain(_ underlyingId: String) -> [Row] {
        optionRows.filter { $0["undID"] as? String == underlyingId }
    }

    func futures(_ underlyingId: String) -> [Row] {
        futureRows.filter { $0["undID"] as? String == underlyingId }
    }

    func searchSymbols(_ query: String) -> [Row] {
        let keyword = query.trimmingCharacters(in: .whitespaces).lowercased()
        if keyword.isEmpty { return [] }
        return (optionRows + futureRows + indexRows + equityRows).filter {
            ($0["name"] as? String ?? "").lowercased().contains(keyword) ||
                ($0["id"] as? String ?? "").lowercased().contains(keyword)
        }
    }

    func topOptions(_ underlyingId: String) -> [Any] {
        (symbols["topOptionsByUnderlying"] as? Row)?[underlyingId] as? [Any] ?? []
    }

    // -------------------------------------------------------------------
    // Margin and brokerage previews (the formulas every example app shares)
    // -------------------------------------------------------------------

    /// Full order value, or 20% of it for intraday; nil when unpriceable.
    func margin(symbolId: String, lots: Int, ltp: Double, productType: String?) -> Double? {
        guard let symbol = byId[symbolId], lots > 0, ltp > 0 else { return nil }
        let lotSize = (symbol["lotSize"] as? NSNumber)?.doubleValue ?? 1.0
        let share = productType == "intraday" ? 0.2 : 1.0
        return Double(lots) * lotSize * ltp * share
    }

    /// 0.03% of the order value (quantity in units), capped at 20; nil when unpriceable.
    func brokerage(symbolId: String, quantity: Int, price: Double) -> Double? {
        guard byId[symbolId] != nil, quantity > 0, price > 0 else { return nil }
        return min(Double(quantity) * price * 0.0003, 20.0)
    }

    // -------------------------------------------------------------------
    // OI and intraday analytics, per underlying (nil when it has none)
    // -------------------------------------------------------------------

    private func analyticsFor(_ underlyingId: String) -> Row? { analytics[underlyingId] as? Row }

    private func oiTable(_ underlyingId: String, _ key: String) -> Any? {
        (analyticsFor(underlyingId)?["oi"] as? Row)?[key]
    }

    func oiAnalysis(_ underlyingId: String) -> Any? { oiTable(underlyingId, "analysisAroundAtm") }
    func oiChange(_ underlyingId: String) -> Any? { oiTable(underlyingId, "changeByStrike") }
    func oi(_ underlyingId: String) -> Any? { oiTable(underlyingId, "byStrike") }

    func pcrIntraday(_ underlyingId: String) -> [Row]? {
        (analyticsFor(underlyingId)?["pcrIntraday"] as? [Row]).map(withResolvedTimes)
    }

    func atmIvIntraday(_ underlyingId: String) -> [Row]? {
        (analyticsFor(underlyingId)?["atmIvIntraday"] as? [Row]).map(withResolvedTimes)
    }

    func atmStraddleIntraday(_ underlyingId: String) -> Row? {
        (analyticsFor(underlyingId)?["atmStraddleIntraday"] as? [String: [Row]])?
            .mapValues(withResolvedTimes)
    }

    /// Rewrites each row's "offsetMinutes" into an absolute "time" (ms epoch), so the series looks live.
    private func withResolvedTimes(_ rows: [Row]) -> [Row] {
        let now = nowMs()
        return rows.map { row in
            var resolved = row
            let offsetMinutes = (row["offsetMinutes"] as? NSNumber)?.int64Value ?? 0
            resolved.removeValue(forKey: "offsetMinutes")
            resolved["time"] = now - offsetMinutes * 60_000
            return resolved
        }
    }

    // -------------------------------------------------------------------
    // Seeds, each row given its `symbol`
    // -------------------------------------------------------------------

    func seedOrders() -> [Row] {
        (seeds["seedOrders"] as! [Row]).map { row in
            var order = row
            order.removeValue(forKey: "symID")
            order.removeValue(forKey: "ordTimeOffsetMinutes")
            order["symbol"] = symbol(row["symID"] as? String ?? "") ?? NSNull()
            if let offset = (row["ordTimeOffsetMinutes"] as? NSNumber)?.int64Value {
                order["ordTime"] = formatOrdTime(offsetMinutes: offset)
            }
            return order
        }
    }

    func seedPositions() -> [Row] {
        (seeds["seedPositions"] as! [Row]).map { row in
            var position = row
            position["symbol"] = symbol(row["symID"] as? String ?? "") ?? NSNull()
            return position
        }
    }

    func seedOcoOrders() -> [Row] { seeds["seedOcoOrders"] as! [Row] }

    private static let ordTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// The "dd-MM-yyyy HH:mm:ss" string `Order.ordTime` expects, `offsetMinutes` ago.
    func formatOrdTime(offsetMinutes: Int64) -> String {
        Self.ordTimeFormatter.string(from: Date().addingTimeInterval(-Double(offsetMinutes) * 60))
    }

    // -------------------------------------------------------------------
    // Candles and ticks: one deterministic curve per symbol, so reloads and
    // live ticks agree
    // -------------------------------------------------------------------

    private func seededUnit(_ seed: String) -> Double {
        var h: Int32 = -2_128_831_035 // FNV-1a offset basis
        for unit in seed.utf16 { h = (h ^ Int32(unit)) &* 16_777_619 }
        return Double(UInt32(bitPattern: h)) / 4_294_967_296.0
    }

    private func latticeNoise(_ symbolId: String, _ ts: Int64, _ spacingMs: Int64) -> Double {
        let n = Int64((Double(ts) / Double(spacingMs)).rounded(.down))
        let frac = Double(ts) / Double(spacingMs) - Double(n)
        let a = seededUnit("\(symbolId):\(spacingMs):\(n)") * 2 - 1
        let b = seededUnit("\(symbolId):\(spacingMs):\(n + 1)") * 2 - 1
        let smooth = frac * frac * (3 - 2 * frac)
        return a + (b - a) * smooth
    }

    private func priceAt(_ symbolId: String, _ ts: Int64) -> Double {
        let base = basePrice(symbolId)
        let wave = latticeNoise(symbolId, ts, 20 * 60_000) * (base * 0.012) +
            latticeNoise(symbolId, ts, 3 * 60_000) * (base * 0.005) +
            latticeNoise(symbolId, ts, 20_000) * (base * 0.0015)
        return max(0.5, base + wave)
    }

    /// `[[time, open, high, low, close, volume], ...]`, the last bar holding
    /// `to`. Bar times sit on the interval grid; high and low are the curve's
    /// extremes inside the bar and volume is seeded per bar, so every load of
    /// the same range returns the same bars.
    func candles(symbolId: String, intervalSeconds: Int, count: Int, to: Int64) -> [[Any]] {
        let intervalMs = Int64(intervalSeconds) * 1000
        guard intervalMs > 0, count > 0 else { return [] }
        let last = Int64((Double(to) / Double(intervalMs)).rounded(.down)) * intervalMs
        return stride(from: count - 1, through: 0, by: -1).map { i -> [Any] in
            let ts = last - Int64(i) * intervalMs
            let samples = [0.0, 0.25, 0.5, 0.75, 1.0].map { priceAt(symbolId, ts + Int64(Double(intervalMs) * $0)) }
            let volume = 1000 + Int((seededUnit("\(symbolId):vol:\(ts)") * 5000).rounded(.down))
            return [ts, samples[0], samples.max()!, samples.min()!, samples[4], volume]
        }
    }

    private var subscribed: Set<String> = []
    private var lastPrices: [String: Double] = [:]

    /// The complete desired set: replaces, never adds.
    func subscribe(_ symbolIds: Set<String>) {
        subscribed = symbolIds
    }

    /// The last ticked price, else the curve's price now.
    func priceOf(_ symbolId: String) -> Double {
        lastPrices[symbolId] ?? priceAt(symbolId, nowMs())
    }

    /// One tick per subscribed symbol id.
    func nextTicks() -> [Row] { subscribed.map(tickFor) }

    private func tickFor(_ symbolId: String) -> Row {
        let base = basePrice(symbolId)
        let now = nowMs()
        let ltp = round2(max(0.05, priceAt(symbolId, now) + (Double.random(in: 0 ..< 1) - 0.5) * (base * 0.0006)))
        lastPrices[symbolId] = ltp
        let tick: Row = [
            "symbolId": symbolId,
            "ltp": ltp,
            "ltq": 10 + Int.random(in: 0 ..< 50),
            "chng": round2(ltp - base),
            "chngPer": round2((ltp - base) / base * 100),
            "ltt": now,
        ]
        return tick.merging(optionOiFields(symbolId)) { _, new in new }
            .merging(depthFor(symbolId, ltp)) { _, new in new }
    }

    // -------------------------------------------------------------------
    // Market depth: 5 bid/ask levels around the tick's ltp, plus day stats
    // (the web example's generator)
    // -------------------------------------------------------------------

    private final class DayStats {
        let open: Double
        var high: Double
        var low: Double
        var volume: Double
        var turnover: Double

        init(open: Double, volume: Double) {
            self.open = open
            high = open
            low = open
            self.volume = volume
            turnover = volume * open
        }
    }

    private static let depthLevels = 5

    // Day high/low/volume only widen or accumulate, so they outlive each book snapshot.
    private var dayStats: [String: DayStats] = [:]

    private func roundToTick(_ value: Double, _ tick: Double) -> Double {
        ((value / tick).rounded() * tick * 1e4).rounded() / 1e4
    }

    private func depthSide(_ start: Double, _ tick: Double, _ direction: Double) -> [Row] {
        (0 ..< Self.depthLevels).map { i in
            // Resting size thins out away from the touch, like a real book.
            let qty = (Double(1300 - i * 250) * (0.6 + Double.random(in: 0 ..< 1) * 0.8)).rounded()
            return [
                "price": roundToTick(start + direction * Double(i) * tick, tick),
                "qty": Int64(qty),
                "orders": max(Int64(1), Int64((qty / 180.0 + Double.random(in: 0 ..< 1) * 2).rounded())),
            ]
        }
    }

    /// Order-book fields merged onto a tick; each is a full snapshot, not a delta.
    private func depthFor(_ symbolId: String, _ ltp: Double) -> Row {
        let base = basePrice(symbolId)
        let rawTick = (byId[symbolId]?["tickSize"] as? NSNumber)?.doubleValue ?? 0
        let tick = rawTick > 0 ? rawTick : 0.05
        let price = roundToTick(max(tick, ltp), tick)
        let stats = dayStats[symbolId] ?? {
            let open = roundToTick(base * (1 + (seededUnit("\(symbolId):open") - 0.5) * 0.01), tick)
            let created = DayStats(open: open, volume: 1_000_000 * (1 + seededUnit("\(symbolId):vol")))
            dayStats[symbolId] = created
            return created
        }()
        stats.high = max(stats.high, price)
        stats.low = min(stats.low, price)
        let ltq = 1 + Int.random(in: 0 ..< 100)
        stats.volume += Double(ltq)
        stats.turnover += Double(ltq) * price

        let bids = depthSide(price - tick, tick, -1)
        let asks = depthSide(price + tick, tick, 1)
        // Totals cover the whole book, not just the five visible levels.
        func bookTotal(_ levels: [Row]) -> Int64 {
            let sum = levels.reduce(Int64(0)) { $0 + ($1["qty"] as? Int64 ?? 0) }
            return Int64((Double(sum) * (1.4 + Double.random(in: 0 ..< 1) * 0.4)).rounded())
        }
        return [
            "bids": bids,
            "asks": asks,
            "totalBuyQty": bookTotal(bids),
            "totalSellQty": bookTotal(asks),
            "open": stats.open,
            "high": stats.high,
            "low": stats.low,
            "prevClose": base,
            "avgTradePrice": roundToTick(stats.turnover / stats.volume, tick),
            "ltq": ltq,
        ]
    }

    // OI and volume on an option tick, for the chain's OI columns: the
    // fixture's per-strike table (else a bell around the ATM), jittered.
    private func optionOiFields(_ symbolId: String) -> Row {
        guard let option = byId[symbolId], let strikeKey = option["strike"] as? String else { return [:] }
        let side = option["optType"] as? String == "CE" ? "calls" : "puts"
        let undId = option["undID"] as? String ?? ""
        let strike = Double(strikeKey) ?? 0
        func table(_ key: String) -> NSNumber? {
            ((oiTable(undId, key) as? Row)?[side] as? Row)?[strikeKey] as? NSNumber
        }

        let fallback = 120_000 * exp(-pow((strike - basePrice(undId)) / 400, 2)) + 20_000
        let baseOi = table("byStrike")?.doubleValue ?? fallback
        let liveOi = Int64((baseOi * (1 + (Double.random(in: 0 ..< 1) - 0.5) * 0.01)).rounded())
        let magnitude = table("changeByStrike")?.int64Value ?? Int64((baseOi * 0.03).rounded())
        let oiChng = (strike / 50).truncatingRemainder(dividingBy: 3) == 0 ? -magnitude : magnitude
        let prevOi = liveOi - oiChng
        return [
            "OI": liveOi,
            "oiChng": oiChng,
            "oiChngPer": prevOi > 0 ? round2(Double(oiChng) / Double(prevOi) * 100) : 0.0,
            "vol": Int64((baseOi * 0.4 * (1 + Double.random(in: 0 ..< 1) * 0.05)).rounded()),
        ]
    }
}
