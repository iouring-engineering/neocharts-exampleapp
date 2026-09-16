package com.example.example_android

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/**
 * Reads the shared fixture (bundled as res/raw/{symbols,oi,orders,positions,
 * oco_orders}, symlinked from apps/mock/) and serves it as plain reads, plus
 * this platform's own native live-tick and candle-walk generation widened to
 * every symbol in the fixture.
 */
class MockDataSource(context: Context) {

    private val fixture: JSONObject = JSONObject().apply {
        for (raw in listOf(
            R.raw.symbols, R.raw.oi, R.raw.orders, R.raw.positions, R.raw.oco_orders
        )) {
            val part = JSONObject(
                context.resources.openRawResource(raw)
                    .bufferedReader()
                    .use { it.readText() }
            )
            part.keys().forEach { key -> put(key, part.get(key)) }
        }
    }

    init {
        val requiredKeys = listOf(
            "niftySymbol", "optionChain", "futureSymbols", "indexSymbols",
            "basePrices", "topOptionsByVolume", "oi", "pcrIntraday",
            "atmStraddleIntraday", "atmIvIntraday", "seedOrders",
            "seedPositions", "seedOcoOrders"
        )
        for (key in requiredKeys) {
            check(fixture.has(key)) { "mock fixture is missing required key: $key" }
        }
    }

    private val niftySymbol: JSONObject = fixture.getJSONObject("niftySymbol")
    private val optionChain: JSONArray = fixture.getJSONArray("optionChain")
    private val futureSymbolsArray: JSONArray = fixture.getJSONArray("futureSymbols")
    private val basePrices: JSONObject = fixture.getJSONObject("basePrices")

    private val livePrices = mutableMapOf<String, Double>()
    private fun priceFor(symbolId: String): Double =
        livePrices.getOrPut(symbolId) { basePrices.optDouble(symbolId, 22600.0) }

    // -------------------------------------------------------------------
    // Static fixture reads
    // -------------------------------------------------------------------

    fun symbolInfo(): String = niftySymbol.toString()

    /** Exchange calendar. `sessions` is a list indexed by weekday (0 = Monday
     * ... 6 = Sunday), each entry a list of "HHMM-HHMM" ranges and an empty
     * list for a non-trading day -- see MarketTiming.fromJson in
     * lib/src/models/market_timing.dart. */
    // Open every hour of every day -- a real exchange trades ~6h on weekdays
    // only, but this is a demo: it should show live movement no matter when
    // someone runs it, not just 09:15-15:30 IST on a weekday.
    fun marketTiming(): String {
        val sessions = JSONArray()
        for (weekday in 0 until 7) {
            val daySessions = JSONArray()
            daySessions.put("0000-2359")
            sessions.put(daySessions)
        }
        return JSONObject().apply {
            put("timezone", "Asia/Kolkata")
            put("sessions", sessions)
            put("holidays", JSONArray())
            put("special", JSONObject())
        }.toString()
    }

    fun futureSymbols(): String = futureSymbolsArray.toString()
    fun indexSymbols(): String = fixture.getJSONArray("indexSymbols").toString()
    /** The bare option chain -- MKTDataInterface.optionSymbols' contract. */
    fun optionSymbols(): String = optionChain.toString()

    /** The option chain with the underlying's own symbol info prepended.
     * MKTDataInterface.fetchOptionDetails requires the first element to be the
     * spot symbol (the one entry without an "optType") so the chart can
     * resolve the spot price. */
    fun fetchOptionDetails(): String {
        val withUnderlying = JSONArray()
        withUnderlying.put(niftySymbol)
        for (i in 0 until optionChain.length()) {
            withUnderlying.put(optionChain.get(i))
        }
        return withUnderlying.toString()
    }
    fun chartTopOptions(): String = fixture.getJSONArray("topOptionsByVolume").toString()

    fun fetchOI(): String = fixture.getJSONObject("oi").getJSONObject("byStrike").toString()
    fun fetchOIChange(): String =
        fixture.getJSONObject("oi").getJSONObject("changeByStrike").toString()
    fun fetchOIAnalysis(): String =
        fixture.getJSONObject("oi").getJSONObject("analysisAroundAtm").toString()

    fun fetchPcrIntraday(): String = withResolvedTimes(fixture.getJSONArray("pcrIntraday")).toString()
    fun fetchAtmIvIntraday(): String = withResolvedTimes(fixture.getJSONArray("atmIvIntraday")).toString()

    fun fetchAtmStraddleIntraday(): String {
        val source = fixture.getJSONObject("atmStraddleIntraday")
        val resolved = JSONObject()
        source.keys().forEach { expiry ->
            resolved.put(expiry, withResolvedTimes(source.getJSONArray(expiry)))
        }
        return resolved.toString()
    }

    /** Rewrites each row's "offsetMinutes" into an absolute "time" (ms epoch) so the series always looks live relative to now. */
    private fun withResolvedTimes(rows: JSONArray): JSONArray {
        val now = System.currentTimeMillis()
        val resolved = JSONArray()
        for (i in 0 until rows.length()) {
            val row = JSONObject(rows.getJSONObject(i).toString())
            val offsetMinutes = row.getLong("offsetMinutes")
            row.remove("offsetMinutes")
            row.put("time", now - offsetMinutes * 60_000)
            resolved.put(row)
        }
        return resolved
    }

    fun seedOrders(): String {
        val rows = withSymbolAttached(fixture.getJSONArray("seedOrders"))
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i)
            if (row.has("ordTimeOffsetMinutes")) {
                val offsetMinutes = row.getLong("ordTimeOffsetMinutes")
                row.remove("ordTimeOffsetMinutes")
                row.put("ordTime", formatOrdTime(offsetMinutes))
            }
        }
        return rows.toString()
    }
    fun seedPositions(): String = withSymbolAttached(fixture.getJSONArray("seedPositions")).toString()
    // No seedOcoOrders() reader: this host reports hasOCO = false and doesn't
    // implement place/modify/cancelOCOOrder, so seeding an OCO marker the user
    // could drag would only surface a not-implemented failure.

    private fun withSymbolAttached(rows: JSONArray): JSONArray {
        val result = JSONArray()
        for (i in 0 until rows.length()) {
            val row = JSONObject(rows.getJSONObject(i).toString())
            row.put("symbol", niftySymbol)
            result.put(row)
        }
        return result
    }

    /** Resolves an "ordTimeOffsetMinutes" fixture field into the "DD-MM-YYYY HH:mm:ss" string
     * order consumers expect for "ordTime" (see TradeInterface.ordersStreamer doc). */
    private val ordTimeFormatter = DateTimeFormatter.ofPattern("dd-MM-yyyy HH:mm:ss")
    private fun formatOrdTime(offsetMinutes: Long): String {
        val instant = Instant.ofEpochMilli(System.currentTimeMillis() - offsetMinutes * 60_000)
        return LocalDateTime.ofInstant(instant, ZoneId.systemDefault()).format(ordTimeFormatter)
    }

    // -------------------------------------------------------------------
    // Native live generation, widened to every fixture symbol
    // -------------------------------------------------------------------

    fun generateOhlcv(symbolId: String, intervalSeconds: Int, barCount: Int): String {
        val interval = intervalSeconds * 1000L
        val endTime = System.currentTimeMillis()
        val bars = JSONArray()
        var price = priceFor(symbolId)

        for (i in barCount - 1 downTo 0) {
            val ts = endTime - i * interval
            val open = price
            val change = (Random.nextDouble() - 0.48) * (open * 0.002)
            val close = max(1.0, open + change)
            val high = max(open, close) + Random.nextDouble() * (open * 0.001)
            val low = max(0.5, min(open, close) - Random.nextDouble() * (open * 0.001))
            val volume = (1000 + Random.nextInt(5000)).toDouble()
            bars.put(JSONArray().apply {
                put(ts); put(open); put(high); put(low); put(close); put(volume)
            })
            price = close
        }
        livePrices[symbolId] = price
        return bars.toString()
    }

    /** One tick per symbol: spot, then every option, then every future -- matching MockChartDataSource.generateTicks()'s breadth. */
    fun nextTicks(): String {
        val ticks = JSONArray()
        ticks.put(tickFor(niftySymbol.getString("id")))
        for (i in 0 until optionChain.length()) {
            ticks.put(tickFor(optionChain.getJSONObject(i).getString("id")))
        }
        for (i in 0 until futureSymbolsArray.length()) {
            ticks.put(tickFor(futureSymbolsArray.getJSONObject(i).getString("id")))
        }
        return ticks.toString()
    }

    private fun tickFor(symbolId: String): JSONObject {
        val base = basePrices.optDouble(symbolId, 22600.0)
        var price = priceFor(symbolId)
        price += (Random.nextDouble() - 0.48) * (base * 0.001)
        price = max(0.05, price)
        livePrices[symbolId] = price
        val ltp = "%.2f".format(price).toDouble()
        return JSONObject().apply {
            put("symbolId", symbolId)
            put("ltp", ltp)
            put("ltq", 10 + Random.nextInt(50))
            put("chng", "%.2f".format(ltp - base).toDouble())
            put("chngPer", "%.2f".format((ltp - base) / base * 100).toDouble())
            put("ltt", System.currentTimeMillis())
        }
    }
}
