package com.example.example_android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Reads the shared fixture straight from apps/mock/ (the test runs in app/). */
class MockDataSourceTest {

    private val data = MockDataSource { name -> File("../../mock/$name.json").readText() }

    private fun nameOf(row: Map<String, Any?>) = row["id"] as String

    @Test
    fun relianceChainAndFuturesAreRelianceOwn() {
        val chain = data.optionChain("RELIANCE")
        assertTrue(chain.isNotEmpty())
        assertTrue(chain.all { it["undID"] == "RELIANCE" })
        assertEquals(1, data.futures("RELIANCE").size)
    }

    @Test
    fun underlyingOfResolvesOptionsAndIsTotalForUnderlyings() {
        val bankNiftyOption = data.optionChain("BANKNIFTY").first()
        assertEquals("BANKNIFTY", nameOf(data.underlyingOf(nameOf(bankNiftyOption))))
        // Only the real row has an exchange; the unknown-id fallback is {id}.
        assertEquals("NSE", data.underlyingOf("TCS")["exchange"])
    }

    @Test
    fun subscribeReplacesTheTickedSet() {
        data.subscribe(setOf("NIFTY", "BANKNIFTY"))
        data.subscribe(setOf("RELIANCE"))
        assertEquals(setOf("RELIANCE"), data.nextTicks().map { it["symbolId"] }.toSet())
    }

    @Test
    fun marginAndBrokerageUseTheSharedFormulas() {
        val option = data.optionChain("NIFTY").first()
        val id = nameOf(option)
        val lotSize = (option["lotSize"] as Number).toDouble()
        val ltp = 120.0

        assertEquals(2 * lotSize * ltp * 0.2, data.margin(id, 2, ltp, "intraday")!!, 1e-9)
        assertEquals(2 * lotSize * ltp, data.margin(id, 2, ltp, "normal")!!, 1e-9)
        assertNull(data.margin("UNKNOWN", 2, ltp, "intraday"))
        assertNull(data.margin(id, 0, ltp, "intraday"))

        assertEquals(130 * 120.0 * 0.0003, data.brokerage(id, 130, 120.0)!!, 1e-9)
        assertEquals(20.0, data.brokerage(id, 13000, 120.0)!!, 1e-9)
        assertNull(data.brokerage(id, 130, 0.0))
    }

    @Test
    fun ticksCarryAFiveLevelBookAroundTheLtp() {
        data.subscribe(setOf("NIFTY"))
        val tick = data.nextTicks().single()
        val ltp = (tick["ltp"] as Number).toDouble()

        @Suppress("UNCHECKED_CAST")
        fun prices(key: String) = (tick[key] as List<Map<String, Any?>>).map { level ->
            assertTrue((level["qty"] as Number).toLong() > 0)
            assertTrue((level["orders"] as Number).toLong() > 0)
            (level["price"] as Number).toDouble()
        }
        val bids = prices("bids")
        val asks = prices("asks")
        assertEquals(5, bids.size)
        assertEquals(5, asks.size)
        assertEquals(bids.sortedDescending(), bids)
        assertEquals(asks.sorted(), asks)
        assertTrue(bids.first() < ltp && ltp < asks.first())
        for (key in listOf("totalBuyQty", "totalSellQty", "open", "high", "low", "prevClose", "avgTradePrice")) {
            assertTrue("$key missing", tick[key] is Number)
        }
    }

    @Test
    fun candlesAreDeterministicAndOnTheIntervalGrid() {
        val to = 1_767_000_123_456L // not on the minute grid
        val first = data.candles("NIFTY", 60, 50, to)
        val second = data.candles("NIFTY", 60, 50, to)
        assertEquals(first, second)

        for (bar in first) {
            val (time, open, high, low, close) = bar.map { it.toDouble() }
            assertEquals(0.0, time % 60_000, 0.0)
            assertTrue(high >= maxOf(open, close) && low <= minOf(open, close))
        }
        // The wicks are real extremes of the curve, not just open/close.
        assertNotEquals(first.map { it[2] }, first.map { maxOf(it[1].toDouble(), it[4].toDouble()) })
        assertEquals(to / 60_000 * 60_000, first.last()[0].toLong())
    }
}
