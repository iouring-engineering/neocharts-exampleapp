package com.example.example_android

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.appcompat.app.AppCompatActivity
import com.example.example_android.databinding.ActivityMainBinding
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    // Tracks whichever FlutterActivity (chart or scalper) is currently on
    // screen, so the "closeRequested" channel call -- which arrives on the
    // engine's messenger, not tied to a specific Activity instance -- knows
    // which one to finish.
    private var activeChartActivity: Activity? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

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

        binding.openFlutterButton.setOnClickListener {
            startActivity(FlutterActivity.withCachedEngine("chart_engine").build(this))
        }
        binding.openScalperButton.setOnClickListener {
            startActivity(FlutterActivity.withCachedEngine("chart_engine").build(this))
        }
    }

    // -------------------------------------------------------------------------
    // Engine warm-up
    // -------------------------------------------------------------------------

    private fun warmUpEngines() {
        val group = FlutterEngineGroup(this)
        val chartEngine = group.createAndRunEngine(
            this, DartExecutor.DartEntrypoint.createDefault()
        )
        registerChannels(chartEngine)
        FlutterEngineCache.getInstance().put("chart_engine", chartEngine)
    }

    // -------------------------------------------------------------------------
    // Channel registration
    // -------------------------------------------------------------------------

    private val orders = mutableListOf<MutableMap<String, Any>>()
    private var orderSink: EventChannel.EventSink? = null
    private var orderCounter = 0

    private fun registerChannels(engine: FlutterEngine) {
        val messenger = engine.dartExecutor.binaryMessenger

        // --- MethodChannel: nxtchart/data ---
        MethodChannel(messenger, "nxtchart/data").setMethodCallHandler { call, result ->
            when (call.method) {
                "symbolInfo" -> result.success(symbolInfo())
                "optionSymbols" -> result.success("[]")
                "marketTiming" -> result.success(marketTiming())
                "hasOCO" -> result.success(false)
                "storageKey" -> result.success("default")
                "underlyingSymbolInfo" -> result.success(null)
                "futureSymbols" -> result.success(null)
                "indexSymbols" -> result.success(null)
                "atmSymbols" -> result.success(null)
                "fetchOptionDetails" -> result.success("[]")
                "chartTopOptions" -> result.success("[]")
                "loadData" -> {
                    val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 60
                    val requiredBars = call.argument<Int>("requiredBars") ?: 200
                    result.success(generateOhlcv(intervalSeconds, requiredBars))
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
                "closeRequested" -> {
                    activeChartActivity?.finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // --- EventChannel: nxtchart/marketData ---
        val tickHandler = Handler(Looper.getMainLooper())
        var lastPrice = 22500.0
        EventChannel(messenger, "nxtchart/marketData")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var tickRunnable: Runnable? = null

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    tickRunnable = object : Runnable {
                        override fun run() {
                            lastPrice += (Random.nextDouble() - 0.48) * 10
                            lastPrice = lastPrice.coerceIn(18000.0, 28000.0)
                            val ltp = "%.2f".format(lastPrice).toDouble()
                            val tick = JSONObject().apply {
                                put("symbolId", "NIFTY")
                                put("ltp", ltp)
                                put("ltq", 10 + Random.nextInt(50))
                                put("chng", "%.2f".format(ltp - 22500).toDouble())
                                put("chngPer",
                                    "%.2f".format((ltp - 22500) / 22500 * 100).toDouble())
                                put("ltt", System.currentTimeMillis())
                            }
                            sink.success(JSONArray().put(tick).toString())
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

        // --- EventChannel: nxtchart/orders ---
        EventChannel(messenger, "nxtchart/orders")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    orderSink = sink
                    emitOrders()
                }

                override fun onCancel(arguments: Any?) {
                    orderSink = null
                }
            })

        // --- Stub EventChannels (no events emitted) ---
        val stub = object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {}
            override fun onCancel(arguments: Any?) {}
        }
        EventChannel(messenger, "nxtchart/positions").setStreamHandler(stub)
        EventChannel(messenger, "nxtchart/tradeEvents").setStreamHandler(stub)
        EventChannel(messenger, "nxtchart/ocoOrders").setStreamHandler(stub)
    }

    private fun emitOrders() {
        val arr = JSONArray()
        orders.forEach { order ->
            arr.put(JSONObject(order as Map<*, *>))
        }
        orderSink?.success(arr.toString())
    }

    // -------------------------------------------------------------------------
    // Mock data helpers
    // -------------------------------------------------------------------------

    private fun symbolInfo(): String = JSONObject().apply {
        put("id", "NIFTY")
        put("name", "NIFTY 50")
        put("lotSize", 50)
        put("precision", 2)
        put("tickSize", 0.05)
    }.toString()

    private fun marketTiming(): String {
        val sessions = JSONObject().apply {
            for (day in listOf("Mon", "Tue", "Wed", "Thu", "Fri")) {
                put(day, JSONObject().apply {
                    put("open", "09:15")
                    put("close", "15:30")
                })
            }
        }
        return JSONObject().apply {
            put("timezone", "Asia/Kolkata")
            put("sessions", sessions)
            put("holidays", JSONArray())
            put("special", JSONObject())
        }.toString()
    }

    private fun generateOhlcv(intervalSeconds: Int, barCount: Int): String {
        val interval = intervalSeconds * 1000L
        val endTime = System.currentTimeMillis()
        val bars = JSONArray()
        var price = 22500.0

        for (i in barCount - 1 downTo 0) {
            val ts = endTime - i * interval
            val open = price
            val change = (Random.nextDouble() - 0.48) * 50
            val close = (open + change).coerceIn(18000.0, 28000.0)
            val high = max(open, close) + Random.nextDouble() * 20
            val low = min(open, close) - Random.nextDouble() * 20
            val volume = (1000 + Random.nextInt(5000)).toDouble()
            bars.put(JSONArray().apply {
                put(ts); put(open); put(high); put(low); put(close); put(volume)
            })
            price = close
        }
        return bars.toString()
    }
}
