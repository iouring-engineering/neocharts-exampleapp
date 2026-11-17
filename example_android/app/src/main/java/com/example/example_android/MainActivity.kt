package com.example.example_android

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.example.example_android.ui.theme.Example_androidTheme
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : AppCompatActivity() {

    private lateinit var mockData: MockDataSource

    // Tracks whichever FlutterActivity (chart or scalper) is currently on
    // screen, so the "closeRequested" channel call -- which arrives on the
    // engine's messenger, not tied to a specific Activity instance -- knows
    // which one to finish.
    private var activeChartActivity: Activity? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        mockData = MockDataSource(applicationContext)

        application.registerActivityLifecycleCallbacks(
            object : Application.ActivityLifecycleCallbacks {
                override fun onActivityResumed(activity: Activity) {
                    if (activity is FlutterActivity) activeChartActivity = activity
                }
                override fun onActivityDestroyed(activity: Activity) {
                    if (activity === activeChartActivity) activeChartActivity = null
                }
                override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
                override fun onActivityStarted(activity: Activity) {}
                override fun onActivityPaused(activity: Activity) {}
                override fun onActivityStopped(activity: Activity) {}
                override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            }
        )

        warmUpEngines()

        setContent {
            Example_androidTheme(dynamicColor = false) {
                LandingScreen(
                    onOpenChart = {
                        startActivity(FlutterActivity.withCachedEngine("chart_engine").build(this))
                    }
                )
            }
        }
    }

    private fun warmUpEngines() {
        val group = FlutterEngineGroup(this)
        val chartEngine = group.createAndRunEngine(
            this, DartExecutor.DartEntrypoint.createDefault()
        )
        registerChannels(chartEngine)
        FlutterEngineCache.getInstance().put("chart_engine", chartEngine)
    }

    private val orders = mutableListOf<MutableMap<String, Any>>()
    private var orderSink: EventChannel.EventSink? = null
    private var orderCounter = 0
    private val alerts = mutableListOf<JSONObject>()
    private var alertSink: EventChannel.EventSink? = null
    private var alertCounter = 0

    private fun registerChannels(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "nxtchart/data").setMethodCallHandler { call, result ->
            when (call.method) {
                "symbolInfo" -> result.success(mockData.symbolInfo())
                "optionSymbols" -> result.success(mockData.optionSymbols())
                "marketTimings" -> result.success(mockData.marketTimings())
                "hasOCO" -> result.success(false)
                "isMarketOrderSupported" -> result.success(true)
                "storageKey" -> result.success("default")
                // Demo brand colors; null brightness follows the system.
                "theme" -> result.success(
                    """{"brightness": null, "colors": {
                        "light": {"primary": "#7B1FA2", "bullish": "#26A69A", "bearish": "#EF5350"},
                        "dark":  {"primary": "#7B1FA2", "bullish": "#26A69A", "bearish": "#EF5350"}}}"""
                )
                "underlyingSymbolInfo" -> result.success(mockData.symbolInfo())
                "futureSymbols" -> result.success(mockData.futureSymbols())
                "indexSymbols" -> result.success(mockData.indexSymbols())
                "atmSymbols" -> result.success(null)
                "fetchOptionDetails" -> result.success(mockData.fetchOptionDetails())
                "chartTopOptions" -> result.success(mockData.chartTopOptions())
                "fetchOI" -> result.success(mockData.fetchOI())
                "fetchOIChange" -> result.success(mockData.fetchOIChange())
                "fetchOIAnalysis" -> result.success(mockData.fetchOIAnalysis())
                "fetchPcrIntraday" -> result.success(mockData.fetchPcrIntraday())
                "fetchAtmStraddleIntraday" -> result.success(mockData.fetchAtmStraddleIntraday())
                "fetchAtmIvIntraday" -> result.success(mockData.fetchAtmIvIntraday())
                // Parameterized replacements (xxxFor) -- scoped to an explicit id
                // instead of "whatever's currently charted." underlyingSymbolInfoFor
                // is called on every chart load; the other 7 aren't called by the
                // SDK yet, but still need a real case here or every call falls
                // through to notImplemented() below. This mock is single-underlying
                // (NIFTY only), so these ignore the given id, same as every ambient
                // member above.
                "underlyingSymbolInfoFor" -> result.success(mockData.symbolInfo())
                "optionSymbolsFor" -> result.success(mockData.optionSymbols())
                "futureSymbolsFor" -> result.success(mockData.futureSymbols())
                "atmSymbolsFor" -> result.success(null)
                "chartTopOptionsFor" -> result.success(mockData.chartTopOptions())
                "fetchPcrIntradayFor" -> result.success(mockData.fetchPcrIntraday())
                "fetchAtmStraddleIntradayFor" -> result.success(mockData.fetchAtmStraddleIntraday())
                "fetchAtmIvIntradayFor" -> result.success(mockData.fetchAtmIvIntraday())
                "loadData" -> {
                    val symbolId = call.argument<String>("symbolId") ?: "NIFTY"
                    val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 60
                    val requiredBars = call.argument<Int>("requiredBars") ?: 200
                    result.success(mockData.generateOhlcv(symbolId, intervalSeconds, requiredBars))
                }
                "placeOrder" -> {
                    val p = JSONObject(call.arguments as? String ?: "{}")
                    orderCounter++
                    val order = mutableMapOf<String, Any>(
                        "symbolID" to p.optString("symID"),
                        "orderID" to "ORD${orderCounter.toString().padStart(3, '0')}",
                        "avgPrice" to p.optDouble("price", 0.0),
                        "type" to p.optString("orderType", "limit"),
                        "netQty" to p.optInt("qty", 0),
                        "fillQty" to 0,
                        "orderAction" to p.optString("orderAction", "buy")
                    )
                    orders.add(order)
                    emitOrders()
                    result.success(null)
                }
                "modifyOrder" -> {
                    val p = JSONObject(call.arguments as? String ?: "{}")
                    val id = p.optString("orderID")
                    orders.indexOfFirst { it["orderID"] == id }.takeIf { it >= 0 }
                        ?.let { idx ->
                            orders[idx]["avgPrice"] = p.optDouble("price", 0.0)
                            orders[idx]["netQty"] = p.optInt("qty", 0)
                            orders[idx]["type"] = p.optString("orderType", "limit")
                            orders[idx]["orderAction"] = p.optString("orderAction", "buy")
                            emitOrders()
                        }
                    result.success(null)
                }
                "cancelOrder" -> {
                    val id = call.argument<String>("orderID") ?: ""
                    orders.removeIf { it["orderID"] == id }
                    emitOrders()
                    result.success(null)
                }
                // Optional host hooks (see ChannelChartInterface.init). This demo
                // keeps every built-in screen and feature, and runs without a
                // home key.
                "homeKey" -> result.success(null)
                "widgetOverrides" -> result.success(listOf<String>())
                "disabledFeatures" -> result.success(listOf<String>())
                // Funds, order-pad previews and alerts (see TradeInterface).
                "fundsData" -> result.success(
                    """{"availableMargin": 347500.0, "usedMargin": 152500.0}"""
                )
                "fetchMargin" -> {
                    val p = JSONObject(call.arguments as? String ?: "{}")
                    val lotSize = JSONObject(mockData.symbolInfo()).optDouble("lotSize", 1.0)
                    val value = p.optDouble("lots", 0.0) * lotSize * p.optDouble("ltp", 0.0)
                    val required = if (p.optString("action") == "Buy") value else value * 3
                    result.success("""{"marginRequired": $required}""")
                }
                "fetchBrokerage" -> result.success(null)
                "createAlert" -> {
                    val p = JSONObject(call.arguments as? String ?: "{}")
                    alertCounter++
                    // Shape per TradeInterface.alertsStreamer.
                    alerts.add(
                        JSONObject()
                            .put("alertId", "ALT${alertCounter.toString().padStart(3, '0')}")
                            .put("symbolInfo", JSONObject(mockData.symbolInfo()))
                            .put("triggerPrice", p.optString("triggerPrice"))
                            .put("enabled", true)
                            .put("triggered", false)
                            .put("createdAt", System.currentTimeMillis())
                    )
                    emitAlerts()
                    result.success(null)
                }
                "modifyAlert" -> {
                    val p = JSONObject(call.arguments as? String ?: "{}")
                    val idx = alerts.indexOfFirst { it.optString("alertId") == p.optString("alertId") }
                    if (idx >= 0) {
                        p.keys().forEach { k -> alerts[idx].put(k, p.get(k)) }
                        emitAlerts()
                    }
                    result.success(null)
                }
                "deleteAlert" -> {
                    val id = call.argument<String>("alertId") ?: ""
                    alerts.removeIf { it.optString("alertId") == id }
                    emitAlerts()
                    result.success(null)
                }
                "closeRequested" -> {
                    activeChartActivity?.finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        val tickHandler = Handler(Looper.getMainLooper())
        EventChannel(messenger, "nxtchart/marketData")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var tickRunnable: Runnable? = null

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    tickRunnable = object : Runnable {
                        override fun run() {
                            sink.success(mockData.nextTicks())
                            tickHandler.postDelayed(this, 1000)
                        }
                    }
                    tickHandler.post(tickRunnable!!)
                }

                override fun onCancel(arguments: Any?) {
                    tickRunnable?.let { tickHandler.removeCallbacks(it) }
                    tickRunnable = null
                }
            })

        EventChannel(messenger, "nxtchart/orders")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    orderSink = sink
                    if (orders.isEmpty()) {
                        orders.addAll(
                            JSONArray(mockData.seedOrders()).let { arr ->
                                (0 until arr.length()).map { i ->
                                    val obj = arr.getJSONObject(i)
                                    obj.keys().asSequence().associateWith { k -> obj.get(k) }
                                        .toMutableMap()
                                }
                            }
                        )
                        // Seeded ids ("ORD001", ...) live in the same numbering
                        // space as generated ones -- start past them so the next
                        // placeOrder() call can't mint a duplicate id.
                        orderCounter = orders.size
                    }
                    emitOrders()
                }

                override fun onCancel(arguments: Any?) {
                    orderSink = null
                }
            })

        var positionsSink: EventChannel.EventSink? = null
        EventChannel(messenger, "nxtchart/positions")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    positionsSink = sink
                    sink.success(mockData.seedPositions())
                }
                override fun onCancel(arguments: Any?) { positionsSink = null }
            })

        EventChannel(messenger, "nxtchart/alerts")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    alertSink = sink
                    emitAlerts()
                }
                override fun onCancel(arguments: Any?) { alertSink = null }
            })

        val stub = object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {}
            override fun onCancel(arguments: Any?) {}
        }
        EventChannel(messenger, "nxtchart/tradeEvents").setStreamHandler(stub)
        // Silent stub, not a seed: this host has no OCO write path (hasOCO is
        // false above and place/modify/cancelOCOOrder fall through to
        // notImplemented), so an emitted OCO order would render a draggable
        // marker whose every interaction fails.
        EventChannel(messenger, "nxtchart/ocoOrders").setStreamHandler(stub)
    }

    private fun emitAlerts() {
        alertSink?.success(JSONArray(alerts).toString())
    }

    private fun emitOrders() {
        val arr = JSONArray()
        orders.forEach { order ->
            arr.put(JSONObject(order as Map<*, *>))
        }
        orderSink?.success(arr.toString())
    }
}
