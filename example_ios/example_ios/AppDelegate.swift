import Flutter
import FlutterPluginRegistrant
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    let engineGroup = FlutterEngineGroup(name: "nxt_chart", project: nil)
    lazy var chartEngine: FlutterEngine = engineGroup.makeEngine(withEntrypoint: nil, libraryURI: nil)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]?
    ) -> Bool {
        chartEngine.run()
        GeneratedPluginRegistrant.register(with: chartEngine)
        registerChannels(messenger: chartEngine.binaryMessenger)
        return true
    }

    // -------------------------------------------------------------------------
    // Channel registration
    // -------------------------------------------------------------------------

    private var orders: [[String: Any]] = []
    private var orderSink: FlutterEventSink?
    private var orderCounter = 0
    private var tickTimer: Timer?
    private var lastPrice: Double = 22500.0

    // Tracks whichever FlutterViewController (chart or scalper) is currently
    // presented, so "closeRequested" -- which arrives on the engine's
    // messenger, not tied to a specific view controller -- knows which one
    // to dismiss. Set by `ViewController.makeFlutterVC`.
    weak var activeChartVC: FlutterViewController?

    private func registerChannels(messenger: FlutterBinaryMessenger) {

        // --- MethodChannel: nxtchart/data ---
        FlutterMethodChannel(name: "nxtchart/data", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                guard let self else { return }
                switch call.method {
                case "symbolInfo":
                    result(self.symbolInfo())
                case "optionSymbols":
                    result("[]")
                case "marketTiming":
                    result(self.marketTiming())
                case "hasOCO":
                    result(false)
                case "storageKey":
                    result("default")
                case "underlyingSymbolInfo", "futureSymbols", "indexSymbols", "atmSymbols":
                    result(nil)
                case "fetchOptionDetails", "chartTopOptions":
                    result("[]")
                case "loadData":
                    let args = call.arguments as? [String: Any]
                    let intervalSeconds = args?["intervalSeconds"] as? Int ?? 60
                    let requiredBars = args?["requiredBars"] as? Int ?? 200
                    result(self.generateOhlcv(
                        intervalSeconds: intervalSeconds,
                        barCount: requiredBars
                    ))
                case "placeOrder":
                    let json = call.arguments as? String ?? "{}"
                    let p = (try? JSONSerialization.jsonObject(
                        with: json.data(using: .utf8)!
                    ) as? [String: Any]) ?? [:]
                    self.orderCounter += 1
                    let id = String(format: "ORD%03d", self.orderCounter)
                    self.orders.append([
                        "symbolID": p["symID"] as? String ?? "",
                        "orderID": id,
                        "avgPrice": p["price"] as? Double ?? 0.0,
                        "type": p["orderType"] as? String ?? "limit",
                        "netQty": p["qty"] as? Int ?? 0,
                        "fillQty": 0,
                        "orderAction": p["orderAction"] as? String ?? "buy",
                    ])
                    self.emitOrders()
                    result(nil)
                case "modifyOrder":
                    let json = call.arguments as? String ?? "{}"
                    let p = (try? JSONSerialization.jsonObject(
                        with: json.data(using: .utf8)!
                    ) as? [String: Any]) ?? [:]
                    let targetId = p["orderID"] as? String ?? ""
                    if let idx = self.orders.firstIndex(where: {
                        $0["orderID"] as? String == targetId
                    }) {
                        self.orders[idx]["avgPrice"] = p["price"] as? Double ?? 0.0
                        self.orders[idx]["netQty"] = p["qty"] as? Int ?? 0
                        self.orders[idx]["type"] = p["orderType"] as? String ?? "limit"
                        self.orders[idx]["orderAction"] =
                            p["orderAction"] as? String ?? "buy"
                        self.emitOrders()
                    }
                    result(nil)
                case "cancelOrder":
                    let args = call.arguments as? [String: Any] ?? [:]
                    let targetId = args["orderID"] as? String ?? ""
                    self.orders.removeAll { $0["orderID"] as? String == targetId }
                    self.emitOrders()
                    result(nil)
                case "closeRequested":
                    self.activeChartVC?.dismiss(animated: true)
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

        // --- EventChannel: nxtchart/marketData ---
        FlutterEventChannel(name: "nxtchart/marketData", binaryMessenger: messenger)
            .setStreamHandler(MarketDataStreamHandler(appDelegate: self))

        // --- EventChannel: nxtchart/orders ---
        FlutterEventChannel(name: "nxtchart/orders", binaryMessenger: messenger)
            .setStreamHandler(OrdersStreamHandler(appDelegate: self))

        // --- Stub EventChannels (no events emitted) ---
        let stub = StubStreamHandler()
        FlutterEventChannel(name: "nxtchart/positions", binaryMessenger: messenger)
            .setStreamHandler(stub)
        FlutterEventChannel(name: "nxtchart/tradeEvents", binaryMessenger: messenger)
            .setStreamHandler(stub)
        FlutterEventChannel(name: "nxtchart/ocoOrders", binaryMessenger: messenger)
            .setStreamHandler(stub)
    }

    func emitOrders() {
        guard let sink = orderSink,
              let data = try? JSONSerialization.data(withJSONObject: orders),
              let json = String(data: data, encoding: .utf8)
        else { return }
        sink(json)
    }

    // -------------------------------------------------------------------------
    // Mock data helpers
    // -------------------------------------------------------------------------

    private func symbolInfo() -> String {
        let obj: [String: Any] = [
            "id": "NIFTY",
            "name": "NIFTY 50",
            "lotSize": 50,
            "precision": 2,
            "tickSize": 0.05,
        ]
        let data = try! JSONSerialization.data(withJSONObject: obj)
        return String(data: data, encoding: .utf8)!
    }

    private func marketTiming() -> String {
        var sessions: [String: Any] = [:]
        for day in ["Mon", "Tue", "Wed", "Thu", "Fri"] {
            sessions[day] = ["open": "09:15", "close": "15:30"]
        }
        let obj: [String: Any] = [
            "timezone": "Asia/Kolkata",
            "sessions": sessions,
            "holidays": [],
            "special": [:],
        ]
        let data = try! JSONSerialization.data(withJSONObject: obj)
        return String(data: data, encoding: .utf8)!
    }

    func generateOhlcv(intervalSeconds: Int, barCount: Int) -> String {
        let interval = TimeInterval(intervalSeconds)
        let endTime = Date().timeIntervalSince1970
        var bars: [[Any]] = []
        var price = 22500.0

        for i in stride(from: barCount - 1, through: 0, by: -1) {
            let ts = Int64((endTime - Double(i) * interval) * 1000)
            let open = price
            let change = (Double.random(in: 0 ..< 1) - 0.48) * 50
            let close = min(max(open + change, 18000.0), 28000.0)
            let high = max(open, close) + Double.random(in: 0 ..< 20)
            let low = min(open, close) - Double.random(in: 0 ..< 20)
            let volume = Double(Int.random(in: 1000 ..< 6000))
            bars.append([ts, open, high, low, close, volume])
            price = close
        }

        let data = try! JSONSerialization.data(withJSONObject: bars)
        return String(data: data, encoding: .utf8)!
    }

    func nextTick() -> String {
        lastPrice += (Double.random(in: 0 ..< 1) - 0.48) * 10
        lastPrice = min(max(lastPrice, 18000.0), 28000.0)
        let ltp = (lastPrice * 100).rounded() / 100
        let obj: [String: Any] = [
            "symbolId": "NIFTY",
            "ltp": ltp,
            "ltq": Int.random(in: 10 ..< 60),
            "chng": (ltp - 22500 * 100).rounded() / 100,
            "chngPer": ((ltp - 22500) / 22500 * 10000).rounded() / 100,
            "ltt": Int64(Date().timeIntervalSince1970 * 1000),
        ]
        let data = try! JSONSerialization.data(withJSONObject: [obj])
        return String(data: data, encoding: .utf8)!
    }
}

// -------------------------------------------------------------------------
// Stream handlers
// -------------------------------------------------------------------------

class StubStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? { nil }

    func onCancel(withArguments arguments: Any?) -> FlutterError? { nil }
}

class MarketDataStreamHandler: NSObject, FlutterStreamHandler {
    private weak var appDelegate: AppDelegate?
    private var timer: Timer?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            guard let self, let ad = self.appDelegate else { return }
            eventSink(ad.nextTick())
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        timer?.invalidate()
        timer = nil
        return nil
    }
}

class OrdersStreamHandler: NSObject, FlutterStreamHandler {
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? {
        appDelegate?.orderSink = eventSink
        appDelegate?.emitOrders()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.orderSink = nil
        return nil
    }
}
