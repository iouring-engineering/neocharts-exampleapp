package com.example.example_android

import kotlin.math.abs

/**
 * The mock broker: orders, positions, OCO groups and alerts, with simulated
 * fills and triggers. Each change is pushed through [emit] as
 * (event channel name, payload); the payload is JSON-encoded by the caller.
 * Mirrors the Flutter example's NeoChartsRepository.
 */
class TradingState(
    private val data: MockDataSource,
    private val emit: (String, Any?) -> Unit,
) {
    private val orders = data.seedOrders().toMutableList()
    private val positions = data.seedPositions().toMutableList()
    private val ocoOrders = data.seedOcoOrders().toMutableList()
    private val alerts = mutableListOf<MutableMap<String, Any?>>()

    // Seeded ids ("ORD001", "OCO001") share a numbering space with new ones:
    // start past them so a new id can't duplicate a seeded one.
    private var orderCounter = orders.size
    private var ocoCounter = ocoOrders.size
    private var alertCounter = 0

    private fun nextId(prefix: String, n: Int) = prefix + n.toString().padStart(3, '0')

    private fun isBuy(action: Any?) = (action as? String).equals("buy", ignoreCase = true)

    private fun int(value: Any?): Int = num(value).toInt()

    // -------------------------------------------------------------------
    // Snapshots
    // -------------------------------------------------------------------

    fun emitOrders() = emit("orders", orders)
    fun emitPositions() = emit("positions", positions)
    fun emitOcoOrders() = emit("ocoOrders", ocoOrders)
    fun emitAlerts() = emit("alerts", alerts)

    private fun feedback(positive: Boolean, message: String) =
        emit("actionFeedback", mapOf("type" to if (positive) "positive" else "negative", "message" to message))

    /** One live step: P&L on every position, then alert and OCO triggers. */
    fun onTick() {
        for (position in positions) {
            val pnl = round2((data.priceOf(position["symID"] as String) - num(position["avgPrice"])) * int(position["netQty"]))
            position["pnl"] = pnl
            position["unrealizedPL"] = pnl
            position["mtm"] = pnl
        }
        emitPositions()
        evaluateAlerts()
        evaluateOcoOrders()
    }

    // -------------------------------------------------------------------
    // Orders
    // -------------------------------------------------------------------

    /** [p] is OrderParams JSON: symID, price, orderType, orderAction, qty, productType, triggerPrice?. */
    fun placeOrder(p: Row) {
        val symbolId = p["symID"] as String
        val orderId = nextId("ORD", ++orderCounter)
        val qty = int(p["qty"])
        orders.add(
            newOrder(
                orderId, symbolId, p["orderType"], p["orderAction"], p["productType"], qty, "open",
                price = if (p["orderType"] == "market") data.priceOf(symbolId) else num(p["price"]),
                avgPrice = num(p["price"]),
                triggerPrice = num(p["triggerPrice"]),
            )
        )
        // An immediate fill against an existing position of the same symbol
        // and product; an order with no such position stays pending.
        positions.firstOrNull { it["symID"] == symbolId && it["productType"] == p["productType"] }
            ?.let { it["netQty"] = int(it["netQty"]) + if (isBuy(p["orderAction"])) qty else -qty }
        emitOrders()
        emitPositions()
        feedback(true, "Order $orderId placed successfully")
    }

    /** [p] is ModifyOrderRequestParams JSON: OrderParams plus orderID. */
    fun modifyOrder(p: Row) {
        val order = orders.firstOrNull { it["orderID"] == p["orderID"] }
            ?: return feedback(false, "Order not found")
        order["price"] = num(p["price"])
        order["avgPrice"] = num(p["price"])
        order["netQty"] = int(p["qty"])
        order["type"] = p["orderType"]
        order["orderAction"] = p["orderAction"]
        order["productType"] = p["productType"]
        p["triggerPrice"]?.let { order["triggerPrice"] = num(it) }
        emitOrders()
        feedback(true, "Order ${p["orderID"]} modified")
    }

    fun cancelOrder(orderId: String) {
        val order = orders.firstOrNull { it["orderID"] == orderId }
            ?: return feedback(false, "Order not found")
        order["orderStatus"] = "cancelled"
        emitOrders()
        feedback(false, "Order $orderId cancelled")
    }

    /** [request] is `{exit: [leg], add: [leg]}`, leg = {action, id, ordType, price, quantity, productType}. */
    fun groupAdjustOrders(request: Row) {
        @Suppress("UNCHECKED_CAST")
        fun legs(key: String) = request[key] as? List<Row> ?: emptyList()
        fun filled(leg: Row) = newOrder(
            nextId("ORD", ++orderCounter), leg["id"] as String, leg["ordType"], leg["action"], leg["productType"],
            int(leg["quantity"]), "completed", price = num(leg["price"]),
        )
        for (leg in legs("exit")) {
            positions.removeAll { it["symID"] == leg["id"] }
            orders.add(filled(leg))
        }
        for (leg in legs("add")) {
            orders.add(filled(leg))
            upsertPosition(leg)
        }
        emitOrders()
        emitPositions()
        feedback(true, "Group orders adjusted")
    }

    /** An order row as `Order.fromJson` reads it; a completed one is fully filled. */
    private fun newOrder(
        orderId: String, symbolId: String, type: Any?, action: Any?, productType: Any?, qty: Int, status: String,
        price: Double, avgPrice: Double = price, triggerPrice: Double = 0.0,
    ): MutableMap<String, Any?> = mutableMapOf(
        "orderID" to orderId,
        "type" to type,
        "orderAction" to action,
        "productType" to productType,
        "avgPrice" to avgPrice,
        "price" to price,
        "netQty" to qty,
        "fillQty" to if (status == "completed") qty else 0,
        "ordTime" to data.formatOrdTime(0),
        "orderStatus" to status,
        "triggerPrice" to triggerPrice,
        "symbol" to data.symbol(symbolId),
    )

    private fun upsertPosition(leg: Row) {
        val symbolId = leg["id"] as String
        val qty = if (isBuy(leg["action"])) int(leg["quantity"]) else -int(leg["quantity"])
        val price = num(leg["price"])
        val existing = positions.firstOrNull { it["symID"] == symbolId && it["productType"] == leg["productType"] }
        if (existing == null) {
            positions.add(
                mutableMapOf(
                    "symID" to symbolId,
                    "displayName" to data.symbol(symbolId)?.get("name"),
                    "netQty" to qty,
                    "avgPrice" to price,
                    "netOrgAvgPrice" to price,
                    "pnl" to 0.0,
                    "realizedPnl" to 0.0,
                    "realizedOrgPnl" to 0.0,
                    "unrealizedPL" to 0.0,
                    "mtm" to 0.0,
                    "multiplier" to 1.0,
                    "priceFactor" to 1.0,
                    "productType" to leg["productType"],
                    "symbol" to data.symbol(symbolId),
                )
            )
            return
        }
        val netQty = int(existing["netQty"]) + qty
        existing["netQty"] = netQty
        existing["avgPrice"] = price
        existing["netOrgAvgPrice"] = price
        if (netQty == 0) positions.remove(existing)
    }

    // -------------------------------------------------------------------
    // OCO (GTT)
    // -------------------------------------------------------------------

    /** [p] is OCOPlaceOrderRequestParams JSON: side, productType, stopPrice, stopQty, symID, targetPrice, targetQty, targetTriggerPrice, groupId?. */
    fun placeOcoOrder(p: Row) {
        ocoCounter++
        val groupId = p["groupId"] as? String ?: nextId("OCO", ocoCounter)
        val symbol = data.symbol(p["symID"] as String)
        val side = p["side"]
        ocoOrders.add(
            mutableMapOf(
                "groupId" to groupId,
                "symID" to p["symID"],
                "name" to symbol?.get("name"),
                "exchange" to symbol?.get("exchange"),
                "side" to side,
                "productType" to p["productType"],
                "stopLoss" to mutableMapOf(
                    "type" to "stopLoss", "side" to side, "triggerPrice" to num(p["stopPrice"]),
                    "qty" to int(p["stopQty"]), "price" to num(p["stopPrice"]), "fillQty" to 0,
                ),
                "target" to mutableMapOf(
                    "type" to "limit", "side" to side, "triggerPrice" to num(p["targetTriggerPrice"]),
                    "qty" to int(p["targetQty"]), "price" to num(p["targetPrice"]), "fillQty" to 0,
                ),
            )
        )
        emitOcoOrders()
        feedback(true, "OCO $groupId created")
    }

    @Suppress("UNCHECKED_CAST")
    fun modifyOcoOrder(p: Row) {
        val groupId = p["groupId"] as? String ?: return
        val oco = ocoOrders.firstOrNull { it["groupId"] == groupId }
            ?: return feedback(false, "OCO not found")
        (oco["stopLoss"] as MutableMap<String, Any?>).apply {
            put("triggerPrice", num(p["stopPrice"]))
            put("price", num(p["stopPrice"]))
        }
        (oco["target"] as MutableMap<String, Any?>).apply {
            put("triggerPrice", num(p["targetTriggerPrice"]))
            put("price", num(p["targetPrice"]))
        }
        emitOcoOrders()
        feedback(true, "OCO $groupId modified")
    }

    fun cancelOcoOrder(groupId: String) {
        ocoOrders.removeAll { it["groupId"] == groupId }
        emitOcoOrders()
        feedback(false, "OCO $groupId cancelled")
    }

    /** A sell OCO (protecting a long) stops below and targets above; a buy OCO the reverse. */
    private fun evaluateOcoOrders() {
        val triggered = ocoOrders.filter { oco ->
            val price = data.priceOf(oco["symID"] as String)
            val stop = num((oco["stopLoss"] as Map<*, *>)["triggerPrice"])
            val target = num((oco["target"] as Map<*, *>)["triggerPrice"])
            if (isBuy(oco["side"])) price >= stop || price <= target else price <= stop || price >= target
        }
        if (triggered.isEmpty()) return
        ocoOrders.removeAll(triggered)
        triggered.forEach { feedback(true, "OCO ${it["groupId"]} triggered") }
        emitOcoOrders()
    }

    // -------------------------------------------------------------------
    // Alerts
    // -------------------------------------------------------------------

    /** [p] is AlertParams JSON: symbolId, ltp, triggerPrice (strings), alertId?. */
    fun createAlert(p: Row) {
        val alertId = nextId("ALERT", ++alertCounter)
        alerts.add(
            mutableMapOf(
                "alertId" to alertId,
                "symbolInfo" to (data.symbol(p["symbolId"] as String) ?: mapOf("id" to p["symbolId"])),
                "triggerPrice" to p["triggerPrice"]?.toString(),
                "enabled" to true,
                "triggered" to false,
                "createdAt" to System.currentTimeMillis(),
            )
        )
        emitAlerts()
        feedback(true, "Alert $alertId created")
    }

    fun modifyAlert(p: Row) {
        val alert = alerts.firstOrNull { it["alertId"] == p["alertId"] } ?: return
        alert["triggerPrice"] = p["triggerPrice"]?.toString()
        emitAlerts()
        feedback(true, "Alert ${p["alertId"]} modified")
    }

    fun deleteAlert(alertId: String) {
        alerts.removeAll { it["alertId"] == alertId }
        emitAlerts()
        feedback(false, "Alert $alertId deleted")
    }

    private fun evaluateAlerts() {
        var changed = false
        for (alert in alerts) {
            if (alert["enabled"] != true || alert["triggered"] == true) continue
            val trigger = (alert["triggerPrice"] as? String)?.toDoubleOrNull() ?: continue
            val symbolId = (alert["symbolInfo"] as Map<*, *>)["id"] as String
            if (abs(data.priceOf(symbolId) - trigger) <= 2.0) {
                alert["triggered"] = true
                changed = true
                feedback(true, "Alert ${alert["alertId"]} triggered")
            }
        }
        if (changed) emitAlerts()
    }
}
