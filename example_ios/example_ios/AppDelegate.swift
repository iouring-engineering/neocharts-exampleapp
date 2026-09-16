import Flutter
import FlutterPluginRegistrant
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let engineGroup = FlutterEngineGroup(name: "nxt_chart", project: nil)
    lazy var chartEngine: FlutterEngine = engineGroup.makeEngine(withEntrypoint: nil, libraryURI: nil)
    let mockData = MockDataSource()

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

    private var orders: [[String: Any]] = []
    fileprivate var orderSink: FlutterEventSink?
    private var orderCounter = 0

    weak var activeChartVC: FlutterViewController?

    private func registerChannels(messenger: FlutterBinaryMessenger) {

        FlutterMethodChannel(name: "nxtchart/data", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                guard let self else { return }
                switch call.method {
                case "symbolInfo":
                    result(self.mockData.symbolInfo())
                case "optionSymbols":
                    result(self.mockData.optionSymbols())
                case "fetchOptionDetails":
                    result(self.mockData.fetchOptionDetails())
                case "marketTiming":
                    result(self.mockData.marketTiming())
                case "hasOCO":
                    result(false)
                case "isMarketOrderSupported":
                    result(true)
                case "storageKey":
                    result("default")
                case "underlyingSymbolInfo":
                    result(self.mockData.symbolInfo())
                case "futureSymbols":
                    result(self.mockData.futureSymbols())
                case "indexSymbols":
                    result(self.mockData.indexSymbols())
                case "atmSymbols":
                    result(nil)
                case "chartTopOptions":
                    result(self.mockData.chartTopOptions())
                case "fetchOI":
                    result(self.mockData.fetchOI())
                case "fetchOIChange":
                    result(self.mockData.fetchOIChange())
                case "fetchOIAnalysis":
                    result(self.mockData.fetchOIAnalysis())
                case "fetchPcrIntraday":
                    result(self.mockData.fetchPcrIntraday())
                case "fetchAtmStraddleIntraday":
                    result(self.mockData.fetchAtmStraddleIntraday())
                case "fetchAtmIvIntraday":
                    result(self.mockData.fetchAtmIvIntraday())
                case "loadData":
                    let args = call.arguments as? [String: Any]
                    let symbolId = args?["symbolId"] as? String ?? "NIFTY"
                    let intervalSeconds = args?["intervalSeconds"] as? Int ?? 60
                    let requiredBars = args?["requiredBars"] as? Int ?? 200
                    result(self.mockData.generateOhlcv(
                        symbolId: symbolId,
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

        FlutterEventChannel(name: "nxtchart/marketData", binaryMessenger: messenger)
            .setStreamHandler(MarketDataStreamHandler(appDelegate: self))

        FlutterEventChannel(name: "nxtchart/orders", binaryMessenger: messenger)
            .setStreamHandler(OrdersStreamHandler(appDelegate: self))

        FlutterEventChannel(name: "nxtchart/positions", binaryMessenger: messenger)
            .setStreamHandler(SeedOnceStreamHandler { [weak self] in self?.mockData.seedPositions() ?? "[]" })
        // Silent stub, not a seed: this host has no OCO write path (hasOCO is
        // false above and place/modify/cancelOCOOrder fall through to
        // FlutterMethodNotImplemented), so an emitted OCO order would render a
        // draggable marker whose every interaction fails.
        FlutterEventChannel(name: "nxtchart/ocoOrders", binaryMessenger: messenger)
            .setStreamHandler(StubStreamHandler())

        FlutterEventChannel(name: "nxtchart/tradeEvents", binaryMessenger: messenger)
            .setStreamHandler(StubStreamHandler())
    }

    func emitOrders() {
        guard let sink = orderSink,
              let data = try? JSONSerialization.data(withJSONObject: orders),
              let json = String(data: data, encoding: .utf8)
        else { return }
        sink(json)
    }

    func nextTick() -> String { mockData.nextTicks() }

    func seedOrdersIfEmpty() {
        guard orders.isEmpty,
              let data = mockData.seedOrders().data(using: .utf8),
              let seeded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }
        orders = seeded
        // Seeded ids ("ORD001", ...) live in the same numbering space as
        // generated ones -- start past them so the next placeOrder() call
        // can't mint a duplicate id.
        orderCounter = orders.count
    }
}

// -------------------------------------------------------------------------
// Stream handlers
// -------------------------------------------------------------------------

class StubStreamHandler: NSObject, FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? { nil }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { nil }
}

/// Emits one fixed JSON payload (from `load()`) once per listener attach, then goes silent -- used for the positions seed stream, which starts with fixture data but doesn't update over time (out of scope, see spec).
class SeedOnceStreamHandler: NSObject, FlutterStreamHandler {
    private let load: () -> String
    init(load: @escaping () -> String) { self.load = load }

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        eventSink(load())
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? { nil }
}

class MarketDataStreamHandler: NSObject, FlutterStreamHandler {
    private weak var appDelegate: AppDelegate?
    private var timer: Timer?

    init(appDelegate: AppDelegate) { self.appDelegate = appDelegate }

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
    init(appDelegate: AppDelegate) { self.appDelegate = appDelegate }

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        appDelegate?.orderSink = eventSink
        appDelegate?.seedOrdersIfEmpty()
        appDelegate?.emitOrders()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.orderSink = nil
        return nil
    }
}
