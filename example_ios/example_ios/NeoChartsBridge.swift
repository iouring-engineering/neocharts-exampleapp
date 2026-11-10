// apps/example_ios/example_ios/NeoChartsBridge.swift
//
// The native side of the NeoCharts host contract over one engine's
// messenger: `neocharts/lifecycle` (native -> Dart), `neocharts/data`
// (Dart -> native) and the six `neocharts/<event>` push channels. Map
// arguments are read by key, JSON-string arguments are parsed, and every
// reply is a JSON string (nil = no data). A real host replaces the mock data
// and broker behind it. Mirrors the Android example's NeoChartsBridge.kt.
import Flutter
import Foundation

final class NeoChartsBridge {

    private static let mountRetries = 30
    private static let mountRetryDelay: TimeInterval = 0.1
    private static let events = ["marketData", "orders", "positions", "actionFeedback", "ocoOrders", "alerts"]
    private static let capabilities = ["oco", "alerts", "oiAnalytics", "intradayAnalytics", "funds", "topOptions", "close"]

    private let lifecycle: FlutterMethodChannel
    private let data: MockDataSource
    private let homeKey: String?
    private let onClose: () -> Void
    private var sinks: [String: FlutterEventSink] = [:]
    private lazy var trading = TradingState(data: data) { [weak self] name, payload in
        self?.push(name, payload)
    }
    private var ticker: Timer?
    private var tick = 0

    init(messenger: FlutterBinaryMessenger, data: MockDataSource, homeKey: String?, onClose: @escaping () -> Void) {
        lifecycle = FlutterMethodChannel(name: "neocharts/lifecycle", binaryMessenger: messenger)
        self.data = data
        self.homeKey = homeKey
        self.onClose = onClose

        FlutterMethodChannel(name: "neocharts/data", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in self?.onDataCall(call, result) }
        for name in Self.events {
            FlutterEventChannel(name: "neocharts/\(name)", binaryMessenger: messenger)
                .setStreamHandler(StreamHandler(
                    onListen: { [weak self] sink in
                        self?.sinks[name] = sink
                        self?.onListen(name)
                    },
                    onCancel: { [weak self] in
                        self?.sinks[name] = nil
                        if name == "marketData" {
                            self?.stopTicking()
                            self?.data.subscribe([])
                        }
                    }
                ))
        }
    }

    // -------------------------------------------------------------------
    // neocharts/lifecycle
    // -------------------------------------------------------------------

    /// Mounts the chart with `themeJson`, then calls `onDone` (true once
    /// mounted). A just-warmed engine may not have registered the channel
    /// yet, so only notImplemented retries, every 100 ms, 30 times. An error
    /// (initFailed) ends at once, so the chart shows the SDK's error view.
    func mount(themeJson: String, onDone: @escaping (Bool) -> Void) {
        invokeMount(themeJson, retries: 0, onDone)
    }

    private func invokeMount(_ themeJson: String, retries: Int, _ onDone: @escaping (Bool) -> Void) {
        lifecycle.invokeMethod("mount", arguments: themeJson) { [weak self] result in
            if let error = result as? FlutterError {
                NSLog("NeoChartsBridge: mount failed: \(error.code): \(error.message ?? "")")
                return onDone(false)
            }
            guard (result as? NSObject) === FlutterMethodNotImplemented else { return onDone(true) }
            if retries >= Self.mountRetries {
                NSLog("NeoChartsBridge: mount failed: lifecycle channel not registered after \(retries) retries")
                onDone(false)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.mountRetryDelay) {
                    self?.invokeMount(themeJson, retries: retries + 1, onDone)
                }
            }
        }
    }

    /// Disposes the mounted chart; its push channels cancel.
    func unmount() {
        lifecycle.invokeMethod("unmount", arguments: nil)
    }

    // -------------------------------------------------------------------
    // neocharts/<event>
    // -------------------------------------------------------------------

    private func push(_ name: String, _ payload: Any) {
        guard let sink = sinks[name] else { return }
        do {
            sink(try JSON.string(payload))
        } catch {
            NSLog("NeoChartsBridge: \(name) push failed: \(error)")
        }
    }

    /// A fresh listener gets the current snapshot; marketData starts the live loop.
    private func onListen(_ name: String) {
        switch name {
        case "marketData": startTicking()
        case "orders": trading.emitOrders()
        case "positions": trading.emitPositions()
        case "ocoOrders": trading.emitOcoOrders()
        case "alerts": trading.emitAlerts()
        default: break
        }
    }

    private func startTicking() {
        stopTicking()
        tick = 0
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.onTimer() }
        }
        ticker?.fire()
    }

    private func onTimer() {
        let ticks = data.nextTicks()
        if !ticks.isEmpty { push("marketData", ticks) }
        trading.onTick()
        // Re-sent every 2 s too, like the web example: a snapshot pushed
        // before a consumer subscribed is otherwise lost.
        tick += 1
        if tick % 2 == 0 {
            trading.emitOrders()
            trading.emitOcoOrders()
            trading.emitAlerts()
        }
    }

    /// Stops the loop only; the subscription is cleared on the marketData cancel.
    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    // -------------------------------------------------------------------
    // neocharts/data
    // -------------------------------------------------------------------

    private func onDataCall(_ call: FlutterMethodCall, _ result: FlutterResult) {
        do {
            result(try reply(to: call).map { try JSON.string($0) })
        } catch ReplyError.notImplemented {
            result(FlutterMethodNotImplemented)
        } catch {
            NSLog("NeoChartsBridge: \(call.method) failed: \(error)")
            result(FlutterError(code: "hostError", message: "\(call.method): \(error)", details: nil))
        }
    }

    private enum ReplyError: Error { case notImplemented }

    /// The reply value (encoded once in `onDataCall`), or nil for void / no data.
    private func reply(to call: FlutterMethodCall) throws -> Any? {
        let args = call.arguments as? [String: Any] ?? [:]
        func text(_ key: String) -> String { args[key] as? String ?? "" }
        func json() throws -> Row {
            guard let text = call.arguments as? String else {
                throw JSON.Invalid(description: "expected a JSON-string argument")
            }
            return try JSON.object(text)
        }

        switch call.method {
        // Core
        case "init":
            return session()
        case "loadData":
            let to = Int64(int(args["to"]))
            return data.candles(
                symbolId: text("symbolId"),
                intervalSeconds: int(args["intervalSeconds"]),
                count: int(args["requiredBars"]),
                to: to > 0 ? to : nowMs()
            )
        case "subscribeMarketData":
            data.subscribe(Set(args["symbolIds"] as? [String] ?? []))
            return nil
        case "searchSymbols": return data.searchSymbols(text("query"))
        case "underlyingOf": return data.underlyingOf(text("symbolId"))
        case "optionChain": return data.optionChain(text("underlyingId"))
        case "futures": return data.futures(text("underlyingId"))
        case "marginFor":
            let p = try json()
            return data.margin(
                symbolId: try p.requireString("symbolId"), lots: int(p["lots"]),
                ltp: number(p["ltp"]), productType: p["productType"] as? String
            )
        case "brokerageFor":
            let p = try json()
            return data.brokerage(
                symbolId: try p.requireString("symbolId"), quantity: int(p["quantity"]),
                price: number(p["price"])
            )
        // Mock: every symbol is tradable. A Bool, so the one encode in
        // `onDataCall` sends `true`; anything else blocks trading.
        case "isTradingEnabled": return true
        case "placeOrder": try trading.placeOrder(json())
        case "modifyOrder": trading.modifyOrder(try json())
        case "cancelOrder": trading.cancelOrder(text("orderId"))
        case "groupAdjustOrders": try trading.groupAdjustOrders(json())
        // oco
        case "placeOcoOrder": try trading.placeOcoOrder(json())
        case "modifyOcoOrder": trading.modifyOcoOrder(try json())
        case "cancelOcoOrder": trading.cancelOcoOrder(text("groupId"))
        // alerts
        case "createAlert": try trading.createAlert(json())
        case "modifyAlert": trading.modifyAlert(try json())
        case "deleteAlert": trading.deleteAlert(text("alertId"))
        // oiAnalytics (the fixture has one expiry, so expiries and times are not filtered)
        case "oiAnalysis": return data.oiAnalysis(text("underlyingSymbolId"))
        case "oiChange": return data.oiChange(text("underlyingSymbolId"))
        case "oi": return data.oi(text("underlyingSymbolId"))
        // intradayAnalytics
        case "pcrIntraday": return data.pcrIntraday(text("underlyingId"))
        case "atmStraddleIntraday": return data.atmStraddleIntraday(text("underlyingId"))
        case "atmIvIntraday": return data.atmIvIntraday(text("underlyingId"))
        // funds, topOptions, close
        case "fetchFunds": return ["availableMargin": 347500.0, "usedMargin": 152500.0]
        case "fetchTopOptions": return data.topOptions(text("underlyingId"))
        case "onClose": onClose()
        // No widgetOverrides are declared, so onOpen* never arrive.
        default: throw ReplyError.notImplemented
        }
        return nil
    }

    /// session.json plus every capability; homeKey only when set.
    private func session() -> Row {
        var session = data.session()
        session["capabilities"] = Self.capabilities
        session["widgetOverrides"] = [String]()
        if let homeKey, !homeKey.trimmingCharacters(in: .whitespaces).isEmpty { session["homeKey"] = homeKey }
        return session
    }
}

/// A closure-backed FlutterStreamHandler.
private final class StreamHandler: NSObject, FlutterStreamHandler {
    private let listen: (@escaping FlutterEventSink) -> Void
    private let cancel: () -> Void

    init(onListen: @escaping (@escaping FlutterEventSink) -> Void, onCancel: @escaping () -> Void) {
        listen = onListen
        cancel = onCancel
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        listen(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        cancel()
        return nil
    }
}
