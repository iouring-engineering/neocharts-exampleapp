package com.example.example_android

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The native side of the NeoCharts host contract over one engine's
 * messenger: `neocharts/lifecycle` (native -> Dart), `neocharts/data`
 * (Dart -> native) and the six `neocharts/<event>` push channels. Map
 * arguments are read by key, JSON-string arguments are parsed, and every
 * reply is a JSON string (null = no data). A real host replaces the mock
 * data and broker behind it.
 */
class NeoChartsBridge(
    messenger: BinaryMessenger,
    private val data: MockDataSource,
    private val homeKey: String,
    private val onClose: () -> Unit,
) {
    private val lifecycle = MethodChannel(messenger, "neocharts/lifecycle")
    private val main = Handler(Looper.getMainLooper())
    private val sinks = mutableMapOf<String, EventChannel.EventSink>()
    private val trading = TradingState(data, ::push)
    private var ticker: Runnable? = null

    init {
        MethodChannel(messenger, "neocharts/data").setMethodCallHandler(::onDataCall)
        for (name in EVENTS) {
            EventChannel(messenger, "neocharts/$name").setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    sinks[name] = sink
                    onListen(name)
                }

                override fun onCancel(arguments: Any?) {
                    sinks.remove(name)
                    if (name == "marketData") {
                        stopTicking()
                        data.subscribe(emptySet())
                    }
                }
            })
        }
    }

    // -------------------------------------------------------------------
    // neocharts/lifecycle
    // -------------------------------------------------------------------

    /** Mounts the chart with [themeJson], then calls [onDone] (true once mounted). */
    fun mount(themeJson: String, onDone: (Boolean) -> Unit) = mountWithRetry(
        invoke = { lifecycle.invokeMethod("mount", themeJson, it) },
        retryLater = { again -> main.postDelayed(again, MOUNT_RETRY_MS) },
    ) { mounted, reason ->
        if (!mounted) Log.w(TAG, "mount failed: $reason")
        onDone(mounted)
    }

    /** Disposes the mounted chart; its push channels cancel. */
    fun unmount() = lifecycle.invokeMethod("unmount", null)

    // -------------------------------------------------------------------
    // neocharts/<event>
    // -------------------------------------------------------------------

    private fun push(name: String, payload: Any?) {
        sinks[name]?.success(Json.stringify(payload))
    }

    /** A fresh listener gets the current snapshot; marketData starts the live loop. */
    private fun onListen(name: String) {
        when (name) {
            "marketData" -> startTicking()
            "orders" -> trading.emitOrders()
            "positions" -> trading.emitPositions()
            "ocoOrders" -> trading.emitOcoOrders()
            "alerts" -> trading.emitAlerts()
        }
    }

    private fun startTicking() {
        stopTicking()
        var tick = 0
        ticker = object : Runnable {
            override fun run() {
                val ticks = data.nextTicks()
                if (ticks.isNotEmpty()) push("marketData", ticks)
                trading.onTick()
                // Re-sent every 2 s too, like the web example: a snapshot
                // pushed before a consumer subscribed is otherwise lost.
                if (++tick % 2 == 0) {
                    trading.emitOrders()
                    trading.emitOcoOrders()
                    trading.emitAlerts()
                }
                main.postDelayed(this, 1000)
            }
        }.also { main.post(it) }
    }

    /** Stops the loop only; the subscription is cleared on the marketData cancel. */
    private fun stopTicking() {
        ticker?.let(main::removeCallbacks)
        ticker = null
    }

    // -------------------------------------------------------------------
    // neocharts/data
    // -------------------------------------------------------------------

    private fun onDataCall(call: MethodCall, result: MethodChannel.Result) {
        val reply: String? = try {
            when (call.method) {
                // Core
                "init" -> Json.stringify(hostSession(data, homeKey))
                "loadData" -> Json.stringify(
                    data.candles(
                        call.text("symbolId"),
                        call.number("intervalSeconds").toInt(),
                        call.number("requiredBars").toInt(),
                        call.number("to").toLong().takeIf { it > 0 } ?: System.currentTimeMillis(),
                    )
                )
                "subscribeMarketData" -> {
                    data.subscribe(call.argument<List<String>>("symbolIds").orEmpty().toSet())
                    null
                }
                "searchSymbols" -> Json.stringify(data.searchSymbols(call.text("query")))
                "underlyingOf" -> Json.stringify(data.underlyingOf(call.text("symbolId")))
                "optionChain" -> Json.stringify(data.optionChain(call.text("underlyingId")))
                "futures" -> Json.stringify(data.futures(call.text("underlyingId")))
                "marginFor" -> call.json().let {
                    data.margin(it["symbolId"] as String, num(it["lots"]).toInt(), num(it["ltp"]), it["productType"] as? String)
                }?.let(Json::stringify)
                "brokerageFor" -> call.json().let {
                    data.brokerage(it["symbolId"] as String, num(it["quantity"]).toInt(), num(it["price"]))
                }?.let(Json::stringify)
                // Mock: every symbol is tradable. Any reply but "true" blocks trading.
                "isTradingEnabled" -> "true"
                "placeOrder" -> { trading.placeOrder(call.json()); null }
                "modifyOrder" -> { trading.modifyOrder(call.json()); null }
                "cancelOrder" -> { trading.cancelOrder(call.text("orderId")); null }
                "groupAdjustOrders" -> { trading.groupAdjustOrders(call.json()); null }
                // oco
                "placeOcoOrder" -> { trading.placeOcoOrder(call.json()); null }
                "modifyOcoOrder" -> { trading.modifyOcoOrder(call.json()); null }
                "cancelOcoOrder" -> { trading.cancelOcoOrder(call.text("groupId")); null }
                // alerts
                "createAlert" -> { trading.createAlert(call.json()); null }
                "modifyAlert" -> { trading.modifyAlert(call.json()); null }
                "deleteAlert" -> { trading.deleteAlert(call.text("alertId")); null }
                // oiAnalytics (the fixture has one expiry, so expiries and times are not filtered)
                "oiAnalysis" -> data.oiAnalysis(call.text("underlyingSymbolId"))?.let(Json::stringify)
                "oiChange" -> data.oiChange(call.text("underlyingSymbolId"))?.let(Json::stringify)
                "oi" -> data.oi(call.text("underlyingSymbolId"))?.let(Json::stringify)
                // intradayAnalytics
                "pcrIntraday" -> data.pcrIntraday(call.text("underlyingId"))?.let(Json::stringify)
                "atmStraddleIntraday" -> data.atmStraddleIntraday(call.text("underlyingId"))?.let(Json::stringify)
                "atmIvIntraday" -> data.atmIvIntraday(call.text("underlyingId"))?.let(Json::stringify)
                // funds, topOptions, close
                "fetchFunds" -> Json.stringify(mapOf("availableMargin" to 347500.0, "usedMargin" to 152500.0))
                "fetchTopOptions" -> Json.stringify(data.topOptions(call.text("underlyingId")))
                "onClose" -> { onClose(); null }
                // No widgetOverrides are declared, so onOpen* never arrive.
                else -> return result.notImplemented()
            }
        } catch (e: Exception) {
            Log.w(TAG, "${call.method} failed", e)
            return result.error("hostError", "${call.method}: ${e.message}", null)
        }
        result.success(reply)
    }

    private fun MethodCall.text(key: String): String = argument<String>(key) ?: ""

    private fun MethodCall.number(key: String): Number = argument<Any>(key) as? Number ?: 0

    /** The call's single JSON-string argument, as an object. */
    private fun MethodCall.json(): Row = Json.parseObject(arguments as String)

    private companion object {
        const val TAG = "NeoChartsBridge"
        val EVENTS = listOf("marketData", "orders", "positions", "actionFeedback", "ocoOrders", "alerts")
    }
}

private const val MOUNT_RETRIES = 30
private const val MOUNT_RETRY_MS = 100L
private val CAPABILITIES = listOf("oco", "alerts", "oiAnalytics", "intradayAnalytics", "funds", "topOptions", "close")

/**
 * One `mount` call through [invoke]. A just-warmed engine may not have
 * registered the channel yet, so only notImplemented retries, through
 * [retryLater], 30 times. An error (initFailed) ends at once, so the chart
 * shows the SDK's error view. [onDone] gets (mounted, failure reason).
 */
internal fun mountWithRetry(
    invoke: (MethodChannel.Result) -> Unit,
    retryLater: (() -> Unit) -> Unit,
    retries: Int = 0,
    onDone: (Boolean, String?) -> Unit,
) {
    invoke(object : MethodChannel.Result {
        override fun success(result: Any?) = onDone(true, null)

        override fun error(code: String, message: String?, details: Any?) = onDone(false, "$code: $message")

        override fun notImplemented() =
            if (retries >= MOUNT_RETRIES) onDone(false, "lifecycle channel not registered after $retries retries")
            else retryLater { mountWithRetry(invoke, retryLater, retries + 1, onDone) }
    })
}

/** session.json plus every capability; homeKey only when set. */
internal fun hostSession(data: MockDataSource, homeKey: String): Row = data.session() +
    mapOf("capabilities" to CAPABILITIES, "widgetOverrides" to emptyList<String>()) +
    (if (homeKey.isBlank()) emptyMap() else mapOf("homeKey" to homeKey))
