package com.example.example_android

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class TradingStateTest {

    private val data = MockDataSource { name -> File("../../mock/$name.json").readText() }
    private val pushed = mutableMapOf<String, Any?>()
    private val trading = TradingState(data) { name, payload -> pushed[name] = payload }

    private fun ocoIds(): List<Any?> {
        trading.emitOcoOrders()
        return (pushed["ocoOrders"] as List<*>).map { (it as Map<*, *>)["groupId"] }
    }

    private fun placeOco(groupId: String, side: String, stop: Double, target: Double) = trading.placeOcoOrder(
        mapOf(
            "groupId" to groupId, "symID" to "RELIANCE", "side" to side, "productType" to "intraday",
            "stopPrice" to stop, "stopQty" to 1, "targetPrice" to target, "targetQty" to 1,
            "targetTriggerPrice" to target,
        )
    )

    @Test
    fun ocoTriggersAreSideAware() {
        val price = data.priceOf("RELIANCE")
        // A buy OCO protects a short: its stop sits above the price, its target below.
        placeOco("BUY_WAITS", "Buy", stop = price * 1.5, target = price * 0.5)
        placeOco("BUY_STOPPED", "Buy", stop = price * 0.9, target = price * 0.5)
        placeOco("SELL_WAITS", "Sell", stop = price * 0.5, target = price * 1.5)
        placeOco("SELL_TARGET", "Sell", stop = price * 0.5, target = price * 0.9)

        trading.onTick()

        assertEquals(listOf("BUY_WAITS", "SELL_WAITS"), ocoIds().filter { it is String && it.contains('_') })
    }

    @Test
    fun aSeededOcoCanBeModified() {
        trading.modifyOcoOrder(mapOf("groupId" to "OCO001", "stopPrice" to 22050.0, "targetPrice" to 23200.0, "targetTriggerPrice" to 23150.0))
        trading.emitOcoOrders()

        val oco = (pushed["ocoOrders"] as List<*>).map { it as Map<*, *> }.single { it["groupId"] == "OCO001" }
        assertEquals(22050.0, ((oco["stopLoss"] as Map<*, *>)["triggerPrice"] as Number).toDouble(), 0.0)
        assertEquals(23150.0, ((oco["target"] as Map<*, *>)["triggerPrice"] as Number).toDouble(), 0.0)
    }
}
