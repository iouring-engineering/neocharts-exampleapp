package com.example.example_android

import android.content.Context
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToLong
import kotlin.random.Random

typealias Row = Map<String, Any?>

/** A wire number: a JSON number, a numeric string, else 0. */
internal fun num(value: Any?): Double = when (value) {
    is Number -> value.toDouble()
    is String -> value.toDoubleOrNull() ?: 0.0
    else -> 0.0
}

internal fun round2(v: Double) = (v * 100).roundToLong() / 100.0

/**
 * Reads the shared fixture (apps/mock/{symbols,oi,orders,positions,oco_orders,
 * session}.json; bundled as res/raw symlinks) and serves per-id reads, plus
 * this platform's own candle and tick generation. [readFixture] maps a file
 * name (without .json) to its text, so tests can read apps/mock/ directly.
 */
class MockDataSource(readFixture: (String) -> String) {

    private val symbols = Json.parseObject(readFixture("symbols"))
    private val analytics = Json.parseObject(readFixture("oi"))
    private val sessionFixture = Json.parseObject(readFixture("session"))
    private val seeds: Row = listOf("orders", "positions", "oco_orders")
        .fold(emptyMap()) { acc, name -> acc + Json.parseObject(readFixture(name)) }

    init {
        val required = listOf(
            "optionChain", "futureSymbols", "indexSymbols", "equitySymbols",
            "basePrices", "topOptionsByUnderlying"
        )
        for (key in required) check(symbols.containsKey(key)) { "symbols.json is missing $key" }
        for (key in listOf("seedOrders", "seedPositions", "seedOcoOrders")) {
            check(seeds.containsKey(key)) { "mock fixture is missing $key" }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun rows(key: String): List<Row> = listOf(symbols, seeds).firstNotNullOf { it[key] } as List<Row>

    private val optionRows = rows("optionChain")
    private val futureRows = rows("futureSymbols")
    private val indexRows = rows("indexSymbols")
    private val equityRows = rows("equitySymbols")
    private val basePrices = symbols["basePrices"] as Map<*, *>

    private val allRows = optionRows + futureRows + indexRows + equityRows
    private val byId: Map<String, Row> = allRows.associateBy { it["id"] as String }

    private fun basePrice(id: String): Double = (basePrices[id] as? Number)?.toDouble() ?: 22600.0

    // -------------------------------------------------------------------
    // Session and symbol reads
    // -------------------------------------------------------------------

    /** session.json with `initialSymbolId` resolved into `initialSymbol`, plus the index symbols. */
    fun session(): Row {
        val initialId = sessionFixture["initialSymbolId"] as String
        val initial = checkNotNull(symbol(initialId)) { "session.json: unknown initialSymbolId $initialId" }
        return sessionFixture - "initialSymbolId" + ("initialSymbol" to initial) + ("indexSymbols" to indexRows)
    }

    fun symbol(id: String): Row? = byId[id]

    /** Total: an underlying (or an unknown id) resolves to itself. */
    fun underlyingOf(symbolId: String): Row {
        val symbol = byId[symbolId] ?: return mapOf("id" to symbolId)
        val undId = symbol["undID"] as? String ?: return symbol
        return (indexRows + equityRows).firstOrNull { it["id"] == undId } ?: symbol
    }

    fun optionChain(underlyingId: String): List<Row> = optionRows.filter { it["undID"] == underlyingId }

    fun futures(underlyingId: String): List<Row> = futureRows.filter { it["undID"] == underlyingId }

    fun searchSymbols(query: String): List<Row> {
        val keyword = query.trim().lowercase()
        if (keyword.isEmpty()) return emptyList()
        return allRows.filter {
            (it["name"] as String).lowercase().contains(keyword) ||
                (it["id"] as String).lowercase().contains(keyword)
        }
    }

    fun topOptions(underlyingId: String): List<Any?> =
        (symbols["topOptionsByUnderlying"] as Map<*, *>)[underlyingId] as? List<*> ?: emptyList<Any?>()

    // -------------------------------------------------------------------
    // Margin and brokerage previews (the formulas every example app shares)
    // -------------------------------------------------------------------

    /** Full order value, or 20% of it for intraday; null when unpriceable. */
    fun margin(symbolId: String, lots: Int, ltp: Double, productType: String?): Double? {
        val symbol = byId[symbolId] ?: return null
        if (lots <= 0 || ltp <= 0) return null
        val lotSize = (symbol["lotSize"] as? Number)?.toDouble() ?: 1.0
        val share = if (productType == "intraday") 0.2 else 1.0
        return lots * lotSize * ltp * share
    }

    /** 0.03% of the order value (quantity in units), capped at 20; null when unpriceable. */
    fun brokerage(symbolId: String, quantity: Int, price: Double): Double? {
        if (byId[symbolId] == null || quantity <= 0 || price <= 0) return null
        return min(quantity * price * 0.0003, 20.0)
    }

    // -------------------------------------------------------------------
    // OI and intraday analytics, per underlying (null when it has none)
    // -------------------------------------------------------------------

    private fun analyticsFor(underlyingId: String): Map<*, *>? = analytics[underlyingId] as? Map<*, *>
    private fun oiTable(underlyingId: String, key: String): Any? =
        (analyticsFor(underlyingId)?.get("oi") as? Map<*, *>)?.get(key)

    fun oiAnalysis(underlyingId: String): Any? = oiTable(underlyingId, "analysisAroundAtm")
    fun oiChange(underlyingId: String): Any? = oiTable(underlyingId, "changeByStrike")
    fun oi(underlyingId: String): Any? = oiTable(underlyingId, "byStrike")

    fun pcrIntraday(underlyingId: String): List<Row>? =
        (analyticsFor(underlyingId)?.get("pcrIntraday") as? List<*>)?.let(::withResolvedTimes)

    fun atmIvIntraday(underlyingId: String): List<Row>? =
        (analyticsFor(underlyingId)?.get("atmIvIntraday") as? List<*>)?.let(::withResolvedTimes)

    fun atmStraddleIntraday(underlyingId: String): Row? =
        (analyticsFor(underlyingId)?.get("atmStraddleIntraday") as? Map<*, *>)
            ?.entries?.associate { (expiry, rows) -> expiry as String to withResolvedTimes(rows as List<*>) }

    /** Rewrites each row's "offsetMinutes" into an absolute "time" (ms epoch), so the series looks live. */
    @Suppress("UNCHECKED_CAST")
    private fun withResolvedTimes(rows: List<*>): List<Row> {
        val now = System.currentTimeMillis()
        return rows.map { row ->
            val map = row as Row
            map - "offsetMinutes" + ("time" to now - (map["offsetMinutes"] as Number).toLong() * 60_000)
        }
    }

    // -------------------------------------------------------------------
    // Seeds, each row given its `symbol`
    // -------------------------------------------------------------------

    fun seedOrders(): List<MutableMap<String, Any?>> = rows("seedOrders").map { row ->
        val order = (row - "symID" - "ordTimeOffsetMinutes").toMutableMap()
        order["symbol"] = byId[row["symID"] as String]
        (row["ordTimeOffsetMinutes"] as? Number)?.let { order["ordTime"] = formatOrdTime(it.toLong()) }
        order
    }

    fun seedPositions(): List<MutableMap<String, Any?>> = rows("seedPositions").map { row ->
        (row + ("symbol" to byId[row["symID"] as String])).toMutableMap()
    }

    fun seedOcoOrders(): List<MutableMap<String, Any?>> = rows("seedOcoOrders").map { it.toMutableMap() }

    private val ordTimeFormatter = DateTimeFormatter.ofPattern("dd-MM-yyyy HH:mm:ss")

    /** The "dd-MM-yyyy HH:mm:ss" string `Order.ordTime` expects, [offsetMinutes] ago. */
    fun formatOrdTime(offsetMinutes: Long): String {
        val instant = Instant.ofEpochMilli(System.currentTimeMillis() - offsetMinutes * 60_000)
        return LocalDateTime.ofInstant(instant, ZoneId.systemDefault()).format(ordTimeFormatter)
    }

    // -------------------------------------------------------------------
    // Candles and ticks: one deterministic curve per symbol, so reloads and
    // live ticks agree
    // -------------------------------------------------------------------

    private fun seededUnit(seed: String): Double {
        var h = -2128831035 // FNV-1a offset basis
        for (c in seed) h = (h xor c.code) * 16777619
        return (h.toLong() and 0xFFFFFFFFL) / 4294967296.0
    }

    private fun latticeNoise(symbolId: String, ts: Long, spacingMs: Long): Double {
        val n = floor(ts.toDouble() / spacingMs).toLong()
        val frac = ts.toDouble() / spacingMs - n
        val a = seededUnit("$symbolId:$spacingMs:$n") * 2 - 1
        val b = seededUnit("$symbolId:$spacingMs:${n + 1}") * 2 - 1
        val smooth = frac * frac * (3 - 2 * frac)
        return a + (b - a) * smooth
    }

    private fun priceAt(symbolId: String, ts: Long): Double {
        val base = basePrice(symbolId)
        val wave = latticeNoise(symbolId, ts, 20 * 60_000L) * (base * 0.012) +
            latticeNoise(symbolId, ts, 3 * 60_000L) * (base * 0.005) +
            latticeNoise(symbolId, ts, 20_000L) * (base * 0.0015)
        return max(0.5, base + wave)
    }

    /**
     * `[[time, open, high, low, close, volume], ...]`, the last bar holding
     * [to]. Bar times sit on the interval grid; high and low are the curve's
     * extremes inside the bar and volume is seeded per bar, so every load of
     * the same range returns the same bars.
     */
    fun candles(symbolId: String, intervalSeconds: Int, count: Int, to: Long): List<List<Number>> {
        val intervalMs = intervalSeconds * 1000L
        val last = Math.floorDiv(to, intervalMs) * intervalMs
        return (count - 1 downTo 0).map { i ->
            val ts = last - i * intervalMs
            val samples = listOf(0.0, 0.25, 0.5, 0.75, 1.0).map { priceAt(symbolId, ts + (intervalMs * it).toLong()) }
            val volume = 1000 + floor(seededUnit("$symbolId:vol:$ts") * 5000).toInt()
            listOf(ts, samples.first(), samples.max(), samples.min(), samples.last(), volume)
        }
    }

    private var subscribed: Set<String> = emptySet()
    private val lastPrices = mutableMapOf<String, Double>()

    /** The complete desired set: replaces, never adds. */
    fun subscribe(symbolIds: Set<String>) {
        subscribed = symbolIds.toSet()
    }

    /** The last ticked price, else the curve's price now. */
    fun priceOf(symbolId: String): Double =
        lastPrices[symbolId] ?: priceAt(symbolId, System.currentTimeMillis())

    /** One tick per subscribed symbol id. */
    fun nextTicks(): List<Row> = subscribed.map(::tickFor)

    private fun tickFor(symbolId: String): Row {
        val base = basePrice(symbolId)
        val now = System.currentTimeMillis()
        val ltp = round2(max(0.05, priceAt(symbolId, now) + (Random.nextDouble() - 0.5) * (base * 0.0006)))
        lastPrices[symbolId] = ltp
        return mapOf(
            "symbolId" to symbolId,
            "ltp" to ltp,
            "ltq" to 10 + Random.nextInt(50),
            "chng" to round2(ltp - base),
            "chngPer" to round2((ltp - base) / base * 100),
            "ltt" to now,
        ) + optionOiFields(symbolId) + depthFor(symbolId, ltp)
    }

    // -------------------------------------------------------------------
    // Market depth: 5 bid/ask levels around the tick's ltp, plus day stats
    // (the web example's generator)
    // -------------------------------------------------------------------

    private class DayStats(val open: Double, var high: Double, var low: Double, var volume: Double, var turnover: Double)

    // Day high/low/volume only widen or accumulate, so they outlive each book snapshot.
    private val dayStats = mutableMapOf<String, DayStats>()

    private fun roundToTick(value: Double, tick: Double) = Math.round(Math.round(value / tick) * tick * 1e4) / 1e4

    private fun depthSide(start: Double, tick: Double, direction: Int): List<Row> = (0 until DEPTH_LEVELS).map { i ->
        // Resting size thins out away from the touch, like a real book.
        val qty = ((1300 - i * 250) * (0.6 + Random.nextDouble() * 0.8)).roundToLong()
        mapOf(
            "price" to roundToTick(start + direction * i * tick, tick),
            "qty" to qty,
            "orders" to max(1L, (qty / 180.0 + Random.nextDouble() * 2).roundToLong()),
        )
    }

    /** Order-book fields merged onto a tick; each is a full snapshot, not a delta. */
    private fun depthFor(symbolId: String, ltp: Double): Row {
        val base = basePrice(symbolId)
        val tick = (byId[symbolId]?.get("tickSize") as? Number)?.toDouble()?.takeIf { it > 0 } ?: 0.05
        val price = roundToTick(max(tick, ltp), tick)
        val stats = dayStats.getOrPut(symbolId) {
            val open = roundToTick(base * (1 + (seededUnit("$symbolId:open") - 0.5) * 0.01), tick)
            val volume = 1_000_000 * (1 + seededUnit("$symbolId:vol"))
            DayStats(open, open, open, volume, volume * open)
        }
        stats.high = max(stats.high, price)
        stats.low = min(stats.low, price)
        val ltq = 1 + Random.nextInt(100)
        stats.volume += ltq
        stats.turnover += ltq * price

        val bids = depthSide(price - tick, tick, -1)
        val asks = depthSide(price + tick, tick, 1)
        // Totals cover the whole book, not just the five visible levels.
        fun bookTotal(levels: List<Row>) =
            (levels.sumOf { it["qty"] as Long } * (1.4 + Random.nextDouble() * 0.4)).roundToLong()
        return mapOf(
            "bids" to bids,
            "asks" to asks,
            "totalBuyQty" to bookTotal(bids),
            "totalSellQty" to bookTotal(asks),
            "open" to stats.open,
            "high" to stats.high,
            "low" to stats.low,
            "prevClose" to base,
            "avgTradePrice" to roundToTick(stats.turnover / stats.volume, tick),
            "ltq" to ltq,
        )
    }

    // OI and volume on an option tick, for the chain's OI columns: the
    // fixture's per-strike table (else a bell around the ATM), jittered.
    private fun optionOiFields(symbolId: String): Row {
        val option = byId[symbolId] ?: return emptyMap()
        val strikeKey = option["strike"] as? String ?: return emptyMap()
        val side = if (option["optType"] == "CE") "calls" else "puts"
        val undId = option["undID"] as? String ?: ""
        val strike = strikeKey.toDouble()
        fun table(key: String) = ((oiTable(undId, key) as? Map<*, *>)?.get(side) as? Map<*, *>)?.get(strikeKey) as? Number

        val fallback = 120_000 * exp(-((strike - basePrice(undId)) / 400).pow(2)) + 20_000
        val baseOi = table("byStrike")?.toDouble() ?: fallback
        val liveOi = (baseOi * (1 + (Random.nextDouble() - 0.5) * 0.01)).roundToLong()
        val magnitude = table("changeByStrike")?.toLong() ?: (baseOi * 0.03).roundToLong()
        val oiChng = if ((strike / 50) % 3 == 0.0) -magnitude else magnitude
        val prevOi = liveOi - oiChng
        return mapOf(
            "OI" to liveOi,
            "oiChng" to oiChng,
            "oiChngPer" to if (prevOi > 0) round2(oiChng.toDouble() / prevOi * 100) else 0.0,
            "vol" to (baseOi * 0.4 * (1 + Random.nextDouble() * 0.05)).roundToLong(),
        )
    }

    companion object {
        private const val DEPTH_LEVELS = 5

        private val rawIds = mapOf(
            "symbols" to R.raw.symbols, "oi" to R.raw.oi, "orders" to R.raw.orders,
            "positions" to R.raw.positions, "oco_orders" to R.raw.oco_orders, "session" to R.raw.session,
        )

        /** The fixture bundled as res/raw. */
        fun fromRawResources(context: Context) = MockDataSource { name ->
            context.resources.openRawResource(rawIds.getValue(name)).bufferedReader().use { it.readText() }
        }
    }
}
