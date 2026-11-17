// apps/example_ios/example_ios/TradingState.swift
//
// The mock broker: orders, positions, OCO groups and alerts, with simulated
// fills and triggers. Each change is pushed through `emit` as (event channel
// name, payload); the caller JSON-encodes the payload. Mirrors the Android
// example's TradingState.kt (and the Flutter example's NeoChartsRepository).
import Foundation

final class TradingState {

    private let data: MockDataSource
    private let emit: (String, Any) -> Void

    private var orders: [Row]
    private var positions: [Row]
    private var ocoOrders: [Row]
    private var alerts: [Row] = []

    // Seeded ids ("ORD001", "OCO001") share a numbering space with new ones:
    // start past them so a new id can't duplicate a seeded one.
    private var orderCounter: Int
    private var ocoCounter: Int
    private var alertCounter = 0

    init(data: MockDataSource, emit: @escaping (String, Any) -> Void) {
        self.data = data
        self.emit = emit
        orders = data.seedOrders()
        positions = data.seedPositions()
        ocoOrders = data.seedOcoOrders()
        orderCounter = orders.count
        ocoCounter = ocoOrders.count
    }

    private func nextId(_ prefix: String, _ n: Int) -> String { prefix + String(format: "%03d", n) }

    private func isBuy(_ action: Any?) -> Bool { (action as? String)?.lowercased() == "buy" }

    /// A JSON-null-safe value for a row.
    private func orNull(_ value: Any?) -> Any { value ?? NSNull() }

    // -------------------------------------------------------------------
    // Snapshots
    // -------------------------------------------------------------------

    func emitOrders() { emit("orders", orders) }
    func emitPositions() { emit("positions", positions) }
    func emitOcoOrders() { emit("ocoOrders", ocoOrders) }
    func emitAlerts() { emit("alerts", alerts) }

    private func feedback(_ positive: Bool, _ message: String) {
        emit("actionFeedback", ["type": positive ? "positive" : "negative", "message": message])
    }

    /// One live step: P&L on every position, then alert and OCO triggers.
    func onTick() {
        for i in positions.indices {
            let symbolId = positions[i]["symID"] as? String ?? ""
            let pnl = round2((data.priceOf(symbolId) - number(positions[i]["avgPrice"])) * Double(int(positions[i]["netQty"])))
            positions[i]["pnl"] = pnl
            positions[i]["unrealizedPL"] = pnl
            positions[i]["mtm"] = pnl
        }
        emitPositions()
        evaluateAlerts()
        evaluateOcoOrders()
    }

    // -------------------------------------------------------------------
    // Orders
    // -------------------------------------------------------------------

    /// `p` is OrderParams JSON: symID, price, orderType, orderAction, qty, productType, triggerPrice?.
    func placeOrder(_ p: Row) throws {
        let symbolId = try p.requireString("symID")
        orderCounter += 1
        let orderId = nextId("ORD", orderCounter)
        let qty = int(p["qty"])
        orders.append(newOrder(
            orderId, symbolId, p["orderType"], p["orderAction"], p["productType"], qty, "open",
            price: p["orderType"] as? String == "market" ? data.priceOf(symbolId) : number(p["price"]),
            avgPrice: number(p["price"]), triggerPrice: number(p["triggerPrice"])
        ))
        // An immediate fill against an existing position of the same symbol
        // and product; an order with no such position stays pending.
        if let i = positionIndex(symbolId, p["productType"]) {
            positions[i]["netQty"] = int(positions[i]["netQty"]) + (isBuy(p["orderAction"]) ? qty : -qty)
        }
        emitOrders()
        emitPositions()
        feedback(true, "Order \(orderId) placed successfully")
    }

    /// `p` is ModifyOrderRequestParams JSON: OrderParams plus orderID.
    func modifyOrder(_ p: Row) {
        let orderId = p["orderID"] as? String
        guard let i = orders.firstIndex(where: { $0["orderID"] as? String == orderId }) else {
            return feedback(false, "Order not found")
        }
        orders[i]["price"] = number(p["price"])
        orders[i]["avgPrice"] = number(p["price"])
        orders[i]["netQty"] = int(p["qty"])
        orders[i]["type"] = orNull(p["orderType"])
        orders[i]["orderAction"] = orNull(p["orderAction"])
        orders[i]["productType"] = orNull(p["productType"])
        if let trigger = p["triggerPrice"], !(trigger is NSNull) {
            orders[i]["triggerPrice"] = number(trigger)
        }
        emitOrders()
        feedback(true, "Order \(orderId ?? "") modified")
    }

    func cancelOrder(_ orderId: String) {
        guard let i = orders.firstIndex(where: { $0["orderID"] as? String == orderId }) else {
            return feedback(false, "Order not found")
        }
        orders[i]["orderStatus"] = "cancelled"
        emitOrders()
        feedback(false, "Order \(orderId) cancelled")
    }

    /// `request` is `{exit: [leg], add: [leg]}`, leg = {action, id, ordType, price, quantity, productType}.
    func groupAdjustOrders(_ request: Row) throws {
        func legs(_ key: String) -> [Row] { request[key] as? [Row] ?? [] }
        for leg in legs("exit") {
            let symbolId = try leg.requireString("id")
            positions.removeAll { $0["symID"] as? String == symbolId }
            orders.append(try filledOrder(leg))
        }
        for leg in legs("add") {
            orders.append(try filledOrder(leg))
            try upsertPosition(leg)
        }
        emitOrders()
        emitPositions()
        feedback(true, "Group orders adjusted")
    }

    private func filledOrder(_ leg: Row) throws -> Row {
        orderCounter += 1
        return newOrder(
            nextId("ORD", orderCounter), try leg.requireString("id"), leg["ordType"], leg["action"],
            leg["productType"], int(leg["quantity"]), "completed", price: number(leg["price"])
        )
    }

    /// An order row as `Order.fromJson` reads it; a completed one is fully filled.
    private func newOrder(
        _ orderId: String, _ symbolId: String, _ type: Any?, _ action: Any?, _ productType: Any?,
        _ qty: Int, _ status: String, price: Double, avgPrice: Double? = nil, triggerPrice: Double = 0
    ) -> Row {
        [
            "orderID": orderId,
            "type": orNull(type),
            "orderAction": orNull(action),
            "productType": orNull(productType),
            "avgPrice": avgPrice ?? price,
            "price": price,
            "netQty": qty,
            "fillQty": status == "completed" ? qty : 0,
            "ordTime": data.formatOrdTime(offsetMinutes: 0),
            "orderStatus": status,
            "triggerPrice": triggerPrice,
            "symbol": orNull(data.symbol(symbolId)),
        ]
    }

    private func positionIndex(_ symbolId: String, _ productType: Any?) -> Int? {
        positions.firstIndex {
            $0["symID"] as? String == symbolId && $0["productType"] as? String == productType as? String
        }
    }

    private func upsertPosition(_ leg: Row) throws {
        let symbolId = try leg.requireString("id")
        let qty = isBuy(leg["action"]) ? int(leg["quantity"]) : -int(leg["quantity"])
        let price = number(leg["price"])
        guard let i = positionIndex(symbolId, leg["productType"]) else {
            positions.append([
                "symID": symbolId,
                "displayName": orNull(data.symbol(symbolId)?["name"]),
                "netQty": qty,
                "avgPrice": price,
                "netOrgAvgPrice": price,
                "pnl": 0.0,
                "realizedPnl": 0.0,
                "realizedOrgPnl": 0.0,
                "unrealizedPL": 0.0,
                "mtm": 0.0,
                "multiplier": 1.0,
                "priceFactor": 1.0,
                "productType": orNull(leg["productType"]),
                "symbol": orNull(data.symbol(symbolId)),
            ])
            return
        }
        let netQty = int(positions[i]["netQty"]) + qty
        positions[i]["netQty"] = netQty
        positions[i]["avgPrice"] = price
        positions[i]["netOrgAvgPrice"] = price
        if netQty == 0 { positions.remove(at: i) }
    }

    // -------------------------------------------------------------------
    // OCO (GTT)
    // -------------------------------------------------------------------

    /// `p` is OCOPlaceOrderRequestParams JSON: side, productType, stopPrice, stopQty, symID, targetPrice, targetQty, targetTriggerPrice, groupId?.
    func placeOcoOrder(_ p: Row) throws {
        ocoCounter += 1
        let groupId = p["groupId"] as? String ?? nextId("OCO", ocoCounter)
        let symbolId = try p.requireString("symID")
        let symbol = data.symbol(symbolId)
        let side = orNull(p["side"])
        ocoOrders.append([
            "groupId": groupId,
            "symID": symbolId,
            "name": orNull(symbol?["name"]),
            "exchange": orNull(symbol?["exchange"]),
            "side": side,
            "productType": orNull(p["productType"]),
            "stopLoss": [
                "type": "stopLoss", "side": side, "triggerPrice": number(p["stopPrice"]),
                "qty": int(p["stopQty"]), "price": number(p["stopPrice"]), "fillQty": 0,
            ] as Row,
            "target": [
                "type": "limit", "side": side, "triggerPrice": number(p["targetTriggerPrice"]),
                "qty": int(p["targetQty"]), "price": number(p["targetPrice"]), "fillQty": 0,
            ] as Row,
        ])
        emitOcoOrders()
        feedback(true, "OCO \(groupId) created")
    }

    func modifyOcoOrder(_ p: Row) {
        guard let groupId = p["groupId"] as? String else { return }
        guard let i = ocoOrders.firstIndex(where: { $0["groupId"] as? String == groupId }) else {
            return feedback(false, "OCO not found")
        }
        var stopLoss = ocoOrders[i]["stopLoss"] as? Row ?? [:]
        stopLoss["triggerPrice"] = number(p["stopPrice"])
        stopLoss["price"] = number(p["stopPrice"])
        var target = ocoOrders[i]["target"] as? Row ?? [:]
        target["triggerPrice"] = number(p["targetTriggerPrice"])
        target["price"] = number(p["targetPrice"])
        ocoOrders[i]["stopLoss"] = stopLoss
        ocoOrders[i]["target"] = target
        emitOcoOrders()
        feedback(true, "OCO \(groupId) modified")
    }

    func cancelOcoOrder(_ groupId: String) {
        ocoOrders.removeAll { $0["groupId"] as? String == groupId }
        emitOcoOrders()
        feedback(false, "OCO \(groupId) cancelled")
    }

    /// A sell OCO (protecting a long) stops below and targets above; a buy OCO the reverse.
    private func evaluateOcoOrders() {
        var triggered: [Row] = []
        ocoOrders = ocoOrders.filter { oco in
            let price = data.priceOf(oco["symID"] as? String ?? "")
            let stop = number((oco["stopLoss"] as? Row)?["triggerPrice"])
            let target = number((oco["target"] as? Row)?["triggerPrice"])
            let hit = isBuy(oco["side"]) ? (price >= stop || price <= target) : (price <= stop || price >= target)
            if hit { triggered.append(oco) }
            return !hit
        }
        if triggered.isEmpty { return }
        for oco in triggered { feedback(true, "OCO \(oco["groupId"] as? String ?? "") triggered") }
        emitOcoOrders()
    }

    // -------------------------------------------------------------------
    // Alerts
    // -------------------------------------------------------------------

    /// AlertParams' triggerPrice is a string; a number is stringified.
    private func priceText(_ value: Any?) -> Any {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        default: return NSNull()
        }
    }

    /// `p` is AlertParams JSON: symbolId, ltp, triggerPrice (strings), alertId?.
    func createAlert(_ p: Row) throws {
        let symbolId = try p.requireString("symbolId")
        alertCounter += 1
        let alertId = nextId("ALERT", alertCounter)
        alerts.append([
            "alertId": alertId,
            "symbolInfo": data.symbol(symbolId) ?? ["id": symbolId],
            "triggerPrice": priceText(p["triggerPrice"]),
            "enabled": true,
            "triggered": false,
            "createdAt": nowMs(),
        ])
        emitAlerts()
        feedback(true, "Alert \(alertId) created")
    }

    func modifyAlert(_ p: Row) {
        let alertId = p["alertId"] as? String
        guard let i = alerts.firstIndex(where: { $0["alertId"] as? String == alertId }) else { return }
        alerts[i]["triggerPrice"] = priceText(p["triggerPrice"])
        emitAlerts()
        feedback(true, "Alert \(alertId ?? "") modified")
    }

    func deleteAlert(_ alertId: String) {
        alerts.removeAll { $0["alertId"] as? String == alertId }
        emitAlerts()
        feedback(false, "Alert \(alertId) deleted")
    }

    private func evaluateAlerts() {
        var changed = false
        for i in alerts.indices {
            guard alerts[i]["enabled"] as? Bool == true, alerts[i]["triggered"] as? Bool != true,
                  let trigger = (alerts[i]["triggerPrice"] as? String).flatMap(Double.init)
            else { continue }
            let symbolId = (alerts[i]["symbolInfo"] as? Row)?["id"] as? String ?? ""
            if abs(data.priceOf(symbolId) - trigger) <= 2.0 {
                alerts[i]["triggered"] = true
                changed = true
                feedback(true, "Alert \(alerts[i]["alertId"] as? String ?? "") triggered")
            }
        }
        if changed { emitAlerts() }
    }
}
