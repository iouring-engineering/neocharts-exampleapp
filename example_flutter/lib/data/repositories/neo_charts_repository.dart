import 'dart:async';
import 'dart:math';

import 'package:neocharts_exampleapp/data/datasources/mock_chart_data_source.dart';
import 'package:neocharts_exampleapp/data/datasources/stream_rate.dart';
import 'package:neocharts_exampleapp/utils/formatting.dart';
import 'package:nxtchart/interface.dart';

export 'package:neocharts_exampleapp/data/datasources/stream_rate.dart';

/// `pcrIntradaySeries`'s keys per range.
const _pcrKeys = {
  PcrRange.three: '3',
  PcrRange.five: '5',
  PcrRange.ten: '10',
  PcrRange.twenty: '20',
  PcrRange.all: 'all',
};

/// Adapts [MockChartDataSource] (the mock market-data "API") to the
/// NeoCharts host contract and every optional capability.
///
/// Owns what isn't pure market data: order/position/alert/OCO state, the
/// streams the chart subscribes to, and parsing the generator's JSON-shaped
/// maps into the SDK's models at this edge.
class NeoChartsRepository
    implements
        NeoChartsHost,
        OcoCapability,
        AlertsCapability,
        OiAnalyticsCapability,
        IntradayAnalyticsCapability {
  NeoChartsRepository({
    this.storageKey = 'scalper_chart',
    this.streamRate = StreamRate.r1,
    this.liveDataEnabled = true,
    this.benchmarkBarCount,
  }) {
    _initialize();
  }

  @override
  final String storageKey;

  final StreamRate streamRate;
  final bool liveDataEnabled;

  /// Overrides the chart's own requested bar count on every [loadData]
  /// call, so a benchmark run can force a dataset size (e.g. 10K/50K).
  final int? benchmarkBarCount;

  final MockChartDataSource _dataSource = MockChartDataSource();

  /// Every symbol, parsed once.
  late final Map<String, SymbolInfo> _symbols = {
    for (final symbol in _dataSource.allSymbols)
      symbol['id'] as String: SymbolInfo.fromJson(symbol),
  };

  // ---------------------------------------------------------------------------
  // Local trading state
  // ---------------------------------------------------------------------------

  Timer? _streamTimer;

  /// The latest [marketData] set; each call replaces it.
  Set<String> _subscribed = const {};

  final _ticksController = StreamController<List<ChartTick>>.broadcast();

  // Each state stream replays its current snapshot to a new listener, so
  // seeded state shows even when no tick re-emits it.
  late final _ordersController = StreamController<List<Order>>.broadcast(
    onListen: _emitOrders,
  );
  late final _positionsController = StreamController<List<Position>>.broadcast(
    onListen: _emitPositions,
  );
  late final _ocoOrdersController = StreamController<List<OCOOrder>>.broadcast(
    onListen: _emitOcoOrders,
  );
  late final _alertsController = StreamController<List<Alert>>.broadcast(
    onListen: _emitAlerts,
  );
  final _feedbackController = StreamController<ActionFeedback>.broadcast();

  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _positions = [];
  final List<Map<String, dynamic>> _ocoOrders = [];
  final List<Map<String, dynamic>> _alerts = [];

  int _orderCounter = 0;
  int _ocoCounter = 0;
  int _alertCounter = 0;

  bool _disposed = false;

  void _initialize() {
    _addOptionPositions(6);

    if (liveDataEnabled) {
      _startStreaming();
    }
  }

  /// Idempotent: both the page and the app dispose it.
  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _streamTimer?.cancel();
    _streamTimer = null;
    _subscribed = const {};

    _ticksController.close();
    _ordersController.close();
    _positionsController.close();
    _ocoOrdersController.close();
    _alertsController.close();
    _feedbackController.close();
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  @override
  SymbolInfo get initialSymbol => _symbols['NIFTY']!;

  /// Open around the clock, so the demo streams at any hour.
  @override
  final Map<String, MarketTiming> marketTimings = {
    'NSE': MarketTiming(
      timezone: 'Asia/Kolkata',
      sessions: List.generate(7, (_) => [SessionTime.fromRange('0000-2359')]),
      holidays: const {},
      special: const {},
    ),
  };

  @override
  late final List<SymbolInfo> indexSymbols = _parsed(_dataSource.indexSymbols);

  @override
  bool get isMarketOrderSupported => true;

  /// Same as the shared fixture's `apps/mock/session.json`.
  @override
  final Map<Segment, ProductTypes> productTypes = {
    Segment.equity: ProductTypes(
      values: const ['intraday', 'delivery'],
      defaultValue: 'intraday',
    ),
    Segment.future: ProductTypes(
      values: const ['intraday', 'normal'],
      defaultValue: 'intraday',
    ),
    Segment.option: ProductTypes(
      values: const ['intraday', 'normal'],
      defaultValue: 'intraday',
    ),
  };

  // ---------------------------------------------------------------------------
  // Market data
  // ---------------------------------------------------------------------------

  @override
  Future<List<OHLC>> loadData(CandleRequest request) async {
    // A benchmark override widens the window backward from `to` to fit the
    // full bar count; the chart's own range would otherwise cap it.
    final barCount = benchmarkBarCount;
    final from = barCount == null
        ? request.from
        : request.to - barCount * request.intervalSeconds * 1000;

    final bars = _dataSource.generateBars(
      symbolId: request.symbolId,
      from: from,
      to: request.to,
      intervalSeconds: request.intervalSeconds,
      requiredBars: barCount ?? request.requiredBars,
    );

    return [for (final bar in bars) OHLC.fromJSON(bar)];
  }

  @override
  Stream<List<ChartTick>> marketData(Set<String> symbolIds) {
    _subscribed = Set.of(symbolIds);

    return _ticksController.stream;
  }

  @override
  Future<List<SymbolInfo>> searchSymbols(String query) async {
    final keyword = query.trim().toLowerCase();

    return [
      for (final symbol in _symbols.values)
        if (keyword.isEmpty ||
            symbol.id.toLowerCase().contains(keyword) ||
            symbol.name.toLowerCase().contains(keyword))
          symbol,
    ];
  }

  @override
  Future<SymbolInfo> underlyingOf(String symbolId) async {
    // A saved layout may hold an id this universe no longer has.
    final symbol = _symbols[symbolId] ?? initialSymbol;

    return symbol.undID.isEmpty ? symbol : _symbols[symbol.undID]!;
  }

  @override
  Future<List<SymbolInfo>> optionChain(String underlyingId) async =>
      _parsed(_dataSource.optionChain(underlyingId));

  @override
  Future<List<SymbolInfo>> futures(String underlyingId) async =>
      _parsed(_dataSource.futures(underlyingId));

  List<SymbolInfo> _parsed(List<Map<String, dynamic>> rows) => [
    for (final row in rows) _symbols[row['id']]!,
  ];

  /// The Funds pill's numbers.
  Future<Funds> fetchFunds() async {
    return const Funds(
      totalBalance: 500000,
      marginAvailable: 347500,
      usedMargin: 152500,
    );
  }

  /// [underlyingId]'s Top 5 panel options, busiest first.
  Future<List<SymbolInfo>> fetchTopOptions(String underlyingId) async =>
      _parsed(_dataSource.topOptions(underlyingId));

  // ---------------------------------------------------------------------------
  // Margin and brokerage previews
  // ---------------------------------------------------------------------------

  /// Mock margin: the full order value, or 20% of it for intraday; null for
  /// an unknown symbol or a non-positive lots/ltp.
  @override
  Future<double?> marginFor(MarginRequest request) async {
    final symbol = _symbols[request.symbolId];
    if (symbol == null || request.lots <= 0 || request.ltp <= 0) return null;

    final share = request.productType == 'intraday' ? 0.2 : 1.0;

    return request.lots * symbol.lotSize * request.ltp * share;
  }

  /// Mock brokerage: 0.03% of the order value, capped at ₹20; null for an
  /// unknown symbol or a non-positive quantity/price.
  @override
  Future<double?> brokerageFor(BrokerageRequest request) async {
    if (!_symbols.containsKey(request.symbolId) ||
        request.quantity <= 0 ||
        request.price <= 0) {
      return null;
    }

    return min(request.quantity * request.price * 0.0003, 20.0);
  }

  /// Mock: every symbol is tradable.
  @override
  Future<bool> isTradingEnabled(String symbolId) async => true;

  /// [symbolId]'s segment default product type.
  String _defaultProductType(String symbolId) =>
      productTypes[_symbols[symbolId]!.segment]!.defaultValue;

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Order>> get orders => _ordersController.stream;

  @override
  Stream<List<Position>> get positions => _positionsController.stream;

  @override
  Stream<ActionFeedback> get actionFeedback => _feedbackController.stream;

  String _nextOrderId() => 'ORD${(++_orderCounter).toString().padLeft(3, '0')}';

  static bool _isBuy(String action) =>
      OrderAction.fromValue(action) == OrderAction.buy;

  @override
  void placeOrder(OrderParams params) {
    final symbolId = params.symID;
    final isMarket = params.orderType == OrderType.market.value;

    final order = _order(
      symbolId: symbolId,
      type: params.orderType,
      action: params.orderAction,
      productType: params.productType,
      avgPrice: params.price,
      price: isMarket ? _dataSource.priceOf(symbolId) : params.price,
      qty: params.qty,
      filled: 0,
      status: 'open',
      triggerPrice: params.triggerPrice ?? 0,
    );

    _orders.add(order);

    // Simulates an immediate fill against an existing position for this
    // symbol and product; an order with no position is left pending.
    _applyFillToPosition(
      symbolId: symbolId,
      productType: params.productType,
      signedQty: _isBuy(params.orderAction) ? params.qty : -params.qty,
    );

    _emitOrders();
    _emitPositions();

    _feedback(
      ActionSentiment.positive,
      'Order ${order['orderID']} placed successfully',
    );
  }

  @override
  void modifyOrder(ModifyOrderRequestParams params) {
    final orderId = params.orderID;

    final index = _orders.indexWhere((order) => order['orderID'] == orderId);

    if (index == -1) {
      _feedback(ActionSentiment.negative, 'Order not found');

      return;
    }

    _orders[index]
      ..['price'] = params.price
      ..['avgPrice'] = params.price
      ..['netQty'] = params.qty
      ..['type'] = params.orderType
      ..['orderAction'] = params.orderAction
      ..['productType'] = params.productType;

    if (params.triggerPrice case final triggerPrice?) {
      _orders[index]['triggerPrice'] = triggerPrice;
    }

    _emitOrders();

    _feedback(ActionSentiment.positive, 'Order $orderId modified');
  }

  @override
  void cancelOrder(String orderId) {
    final index = _orders.indexWhere((order) => order['orderID'] == orderId);

    if (index == -1) {
      _feedback(ActionSentiment.negative, 'Order not found');

      return;
    }

    _orders[index]['orderStatus'] = 'cancelled';

    _emitOrders();

    _feedback(ActionSentiment.negative, 'Order $orderId cancelled');
  }

  @override
  void groupAdjustOrders(GroupAdjustRequest request) {
    for (final leg in request.exit) {
      _positions.removeWhere((position) => position['symID'] == leg.symID);

      _orders.add(_filledOrder(leg));
    }

    for (final leg in request.add) {
      _orders.add(_filledOrder(leg));

      _upsertPosition(
        symbolId: leg.symID,
        quantity: _isBuy(leg.orderAction) ? leg.qty : -leg.qty,
        price: leg.price,
        productType: leg.productType,
      );
    }

    _emitOrders();
    _emitPositions();

    _feedback(ActionSentiment.positive, 'Group orders adjusted');
  }

  Map<String, dynamic> _filledOrder(OrderParams leg) => _order(
    symbolId: leg.symID,
    type: leg.orderType,
    action: leg.orderAction,
    productType: leg.productType,
    avgPrice: leg.price,
    price: leg.price,
    qty: leg.qty,
    filled: leg.qty,
    status: 'completed',
  );

  Map<String, dynamic> _order({
    required String symbolId,
    required String type,
    required String action,
    required String productType,
    required double avgPrice,
    required double price,
    required int qty,
    required int filled,
    required String status,
    Object triggerPrice = 0,
  }) => {
    'orderID': _nextOrderId(),
    'type': type,
    'orderAction': action,
    'productType': productType,
    'avgPrice': avgPrice,
    'price': price,
    'netQty': qty,
    'fillQty': filled,
    'ordTime': formatDateTime(DateTime.now()),
    'orderStatus': status,
    'triggerPrice': triggerPrice,
    'symbol': _dataSource.symbolForId(symbolId),
  };

  // ---------------------------------------------------------------------------
  // OCO (GTT)
  // ---------------------------------------------------------------------------

  @override
  Stream<List<OCOOrder>> get ocoOrders => _ocoOrdersController.stream;

  @override
  void placeOcoOrder(OCOPlaceOrderRequestParams params) {
    _ocoCounter++;

    final groupId =
        params.groupId ?? 'OCO${_ocoCounter.toString().padLeft(3, '0')}';

    final symbol = _dataSource.symbolForId(params.symID);

    final side = params.side.value;

    _ocoOrders.add({
      'groupId': groupId,
      'symID': params.symID,
      'name': symbol['name'],
      'exchange': symbol['exchange'],
      'side': side,
      'productType': params.productType,
      'stopLoss': <String, dynamic>{
        'type': 'stopLoss',
        'side': side,
        'triggerPrice': params.stopTriggerPrice,
        'qty': params.stopQty,
        'price': params.stopPrice,
        'fillQty': 0,
      },
      'target': <String, dynamic>{
        'type': 'limit',
        'side': side,
        'triggerPrice': params.targetTriggerPrice,
        'qty': params.targetQty,
        'price': params.targetPrice,
        'fillQty': 0,
      },
    });

    _emitOcoOrders();

    _feedback(ActionSentiment.positive, 'OCO $groupId created');
  }

  @override
  void modifyOcoOrder(OCOPlaceOrderRequestParams params) {
    final groupId = params.groupId;

    final index = _ocoOrders.indexWhere((oco) => oco['groupId'] == groupId);

    if (index == -1) {
      _feedback(ActionSentiment.negative, 'OCO not found');

      return;
    }

    final oco = _ocoOrders[index];

    (oco['stopLoss'] as Map<String, dynamic>)
      ..['triggerPrice'] = params.stopTriggerPrice
      ..['price'] = params.stopPrice
      ..['qty'] = params.stopQty;

    (oco['target'] as Map<String, dynamic>)
      ..['triggerPrice'] = params.targetTriggerPrice
      ..['price'] = params.targetPrice
      ..['qty'] = params.targetQty;

    _emitOcoOrders();

    _feedback(ActionSentiment.positive, 'OCO $groupId modified');
  }

  @override
  void cancelOcoOrder(String groupId) {
    _ocoOrders.removeWhere((oco) => oco['groupId'] == groupId);

    _emitOcoOrders();

    _feedback(ActionSentiment.negative, 'OCO $groupId cancelled');
  }

  // ---------------------------------------------------------------------------
  // Alerts
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Alert>> get alerts => _alertsController.stream;

  @override
  void createAlert(AlertParams params) {
    _alertCounter++;

    final alertId = 'ALERT${_alertCounter.toString().padLeft(3, '0')}';

    _alerts.add(
      _alert(alertId, params.symbolId, params.triggerPrice, enabled: true),
    );

    _emitAlerts();

    _feedback(ActionSentiment.positive, 'Alert $alertId created');
  }

  Map<String, dynamic> _alert(
    String alertId,
    String symbolId,
    String triggerPrice, {
    required bool enabled,
  }) => {
    'alertId': alertId,
    'symbolInfo': _dataSource.symbolForId(symbolId),
    'triggerPrice': triggerPrice,
    'enabled': enabled,
    'triggered': false,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };

  @override
  void modifyAlert(AlertParams params) {
    final alertId = params.alertId;

    final index = _alerts.indexWhere((alert) => alert['alertId'] == alertId);

    if (index == -1) {
      _feedback(ActionSentiment.negative, 'Alert not found');

      return;
    }

    _alerts[index]['triggerPrice'] = params.triggerPrice;

    _emitAlerts();

    _feedback(ActionSentiment.positive, 'Alert $alertId modified');
  }

  @override
  void deleteAlert(String alertId) {
    _alerts.removeWhere((alert) => alert['alertId'] == alertId);

    _emitAlerts();

    _feedback(ActionSentiment.negative, 'Alert $alertId deleted');
  }

  // ---------------------------------------------------------------------------
  // OI and intraday analytics
  // ---------------------------------------------------------------------------

  @override
  Future<OIAnalysisSnapshot> oiAnalysis({
    required String underlyingSymbolId,
    required String expiry,
    required int timeFrom,
    required int timeTo,
  }) async {
    final json = _dataSource.oiAnalysisAroundAtm(underlyingSymbolId);

    Map<double, OIAnalysisPoint> side(String name) => {
      for (final MapEntry(:key, :value)
          in (json[name] as Map<String, dynamic>).entries)
        double.parse(key): OIAnalysisPoint.fromJson(
          value as Map<String, dynamic>,
        ),
    };

    return OIAnalysisSnapshot(calls: side('calls'), puts: side('puts'));
  }

  @override
  Future<OIStrikeValues> oiChange({
    required String underlyingSymbolId,
    required List<String> expiries,
    required int timeFrom,
    required int timeTo,
  }) async => _strikeValues(_dataSource.oiChangeByStrike(underlyingSymbolId));

  @override
  Future<OIStrikeValues> oi({
    required String underlyingSymbolId,
    required List<String> expiries,
  }) async => _strikeValues(_dataSource.oiByStrike(underlyingSymbolId));

  OIStrikeValues _strikeValues(Map<String, dynamic> json) {
    Map<double, double> side(String name) => {
      for (final MapEntry(:key, :value)
          in (json[name] as Map<String, dynamic>).entries)
        double.parse(key): (value as num).toDouble(),
    };

    return OIStrikeValues(calls: side('calls'), puts: side('puts'));
  }

  @override
  Future<List<PcrHistoryPoint>> pcrIntraday(String underlyingId) async {
    return [
      for (final row in _dataSource.pcrIntradaySeries(underlyingId))
        (
          time: row['time'] as int,
          price: (row['price'] as num).toDouble(),
          pcrByRange: {
            for (final MapEntry(:key, :value) in _pcrKeys.entries)
              key: ((row['pcr'] as Map<String, dynamic>)[value] as num)
                  .toDouble(),
          },
        ),
    ];
  }

  @override
  Future<List<ChartPoints>> atmStraddleIntraday(String underlyingId) async {
    return [
      for (final MapEntry(key: expiry, value: candles)
          in _dataSource.atmStraddleIntradaySeries(underlyingId).entries)
        for (final candle in candles)
          ChartPoints(
            time: candle['time'] as int,
            price: 0,
            points: (candle['atmStraddlePrice'] as num).toDouble(),
            expiry: expiry,
          ),
    ];
  }

  @override
  Future<List<ChartPoints>> atmIvIntraday(String underlyingId) async {
    return [
      for (final candle in _dataSource.atmIvIntradaySeries(underlyingId))
        if ((candle['atmIv'] as num) > 0)
          ChartPoints(
            time: candle['time'] as int,
            price: 0,
            points: (candle['atmIv'] as num).toDouble(),
          ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Local streaming engine
  // ---------------------------------------------------------------------------

  void _startStreaming() {
    _streamTimer?.cancel();

    _streamTimer = Timer.periodic(streamRate.interval, (_) {
      if (_disposed) return;

      _emitMarketTick();
      _updatePositions();
      _evaluateAlerts();
      _evaluateOcoOrders();
    });
  }

  void _emitMarketTick() {
    final ticks = _dataSource.generateTicks(_subscribed);

    if (ticks.isEmpty) return;

    _ticksController.add([for (final tick in ticks) ChartTick.fromMap(tick)]);
  }

  // ---------------------------------------------------------------------------
  // Position handling
  // ---------------------------------------------------------------------------

  void _upsertPosition({
    required String symbolId,
    required int quantity,
    required double price,
    required String productType,
  }) {
    final index = _positions.indexWhere(
      (position) =>
          position['symID'] == symbolId &&
          position['productType'] == productType,
    );

    if (index == -1) {
      _positions.add(
        _position(
          symbolId: symbolId,
          netQty: quantity,
          avgPrice: price,
          productType: productType,
        ),
      );

      return;
    }

    final position = _positions[index];

    final newQty = (toInt(position['netQty']) ?? 0) + quantity;

    position['netQty'] = newQty;
    position['avgPrice'] = price;
    position['netOrgAvgPrice'] = price;

    if (newQty == 0) {
      _positions.removeAt(index);
    }
  }

  // Fills against an existing position of the same product only. One that
  // nets to zero stays at netQty 0, so it flips to closed, not disappears.
  void _applyFillToPosition({
    required String symbolId,
    required String productType,
    required int signedQty,
  }) {
    final index = _positions.indexWhere(
      (position) =>
          position['symID'] == symbolId &&
          position['productType'] == productType,
    );
    if (index == -1) return;

    final position = _positions[index];
    final newQty = (toInt(position['netQty']) ?? 0) + signedQty;
    position['netQty'] = newQty;
  }

  Map<String, dynamic> _position({
    required String symbolId,
    required int netQty,
    required double avgPrice,
    required String productType,
    double pnl = 0.0,
  }) {
    final symbol = _dataSource.symbolForId(symbolId);

    return {
      'symID': symbolId,
      'displayName': symbol['name'],
      'netQty': netQty,
      'avgPrice': avgPrice,
      'netOrgAvgPrice': avgPrice,
      'pnl': pnl,
      'realizedPnl': 0.0,
      'realizedOrgPnl': 0.0,
      'unrealizedPL': pnl,
      'mtm': pnl,
      'multiplier': 1.0,
      'priceFactor': 1.0,
      'productType': productType,
      'symbol': symbol,
    };
  }

  void _updatePositions() {
    for (final position in _positions) {
      final qty = toInt(position['netQty']) ?? 0;

      final avgPrice = toDouble(position['avgPrice']);

      final price = _dataSource.priceOf(position['symID'] as String);

      final pnl = roundTo((price - avgPrice) * qty, 2);

      position['pnl'] = pnl;

      position['unrealizedPL'] = pnl;

      position['mtm'] = pnl;
    }

    _emitPositions();
  }

  // Up to [count] NIFTY option positions, alternating long normal and
  // short intraday, each a distinct symbol.
  void _addOptionPositions(int count) {
    final options = _dataSource.optionChain('NIFTY').take(count).toList();

    for (var i = 0; i < options.length; i++) {
      final symbolId = options[i]['id'] as String;

      final currentPrice = _dataSource.priceOf(symbolId);

      final netQty = i.isEven ? 50 : -25;

      final avgPrice = (currentPrice + (i.isEven ? -5 : 5)).clamp(100.0, 300.0);

      _positions.add(
        _position(
          symbolId: symbolId,
          netQty: netQty,
          avgPrice: avgPrice,
          productType: i.isEven ? 'normal' : 'intraday',
          pnl: (currentPrice - avgPrice) * netQty,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Alert and OCO triggers
  // ---------------------------------------------------------------------------

  void _evaluateAlerts() {
    var changed = false;

    for (final alert in _alerts) {
      if (alert['enabled'] != true || alert['triggered'] == true) {
        continue;
      }

      final trigger = double.tryParse(alert['triggerPrice']?.toString() ?? '');

      if (trigger == null) {
        continue;
      }

      final symbolId = (alert['symbolInfo'] as Map<String, dynamic>)['id'];

      if ((_dataSource.priceOf(symbolId as String) - trigger).abs() <= 2.0) {
        alert['triggered'] = true;
        changed = true;

        _feedback(
          ActionSentiment.positive,
          'Alert ${alert['alertId']} triggered',
        );
      }
    }

    if (changed) {
      _emitAlerts();
    }
  }

  void _evaluateOcoOrders() {
    final triggered = <String>[];

    for (final oco in _ocoOrders) {
      final price = _dataSource.priceOf(oco['symID'] as String);

      final stopLoss = oco['stopLoss'] as Map<String, dynamic>;

      final target = oco['target'] as Map<String, dynamic>;

      final stop = toDouble(stopLoss['triggerPrice']);

      final goal = toDouble(target['triggerPrice']);

      // A sell OCO protects a long (SL below, TP above); a buy OCO protects
      // a short (SL above, TP below).
      final hit = _isBuy(oco['side'] as String)
          ? price >= stop || price <= goal
          : price <= stop || price >= goal;

      if (hit) {
        triggered.add(oco['groupId'] as String);
      }
    }

    for (final groupId in triggered) {
      _ocoOrders.removeWhere((oco) => oco['groupId'] == groupId);

      _feedback(ActionSentiment.positive, 'OCO $groupId triggered');
    }

    if (triggered.isNotEmpty) {
      _emitOcoOrders();
    }
  }

  // ---------------------------------------------------------------------------
  // Test-only seeding hooks
  // ---------------------------------------------------------------------------

  /// Adds a synthetic NIFTY position so Patrol tests can exercise position
  /// and OCO flows; [avgPrice] snaps to the tick size, and [productType]
  /// defaults to NIFTY's segment default.
  void seedPosition({int netQty = 75, double? avgPrice, String? productType}) {
    _positions.add(
      _position(
        symbolId: 'NIFTY',
        netQty: netQty,
        avgPrice: _snapToTick(avgPrice ?? _dataSource.lastPrice),
        productType: productType ?? _defaultProductType('NIFTY'),
      ),
    );

    _emitPositions();
  }

  /// Replaces every position with up to [count] distinct NIFTY option
  /// positions (clamped to the chain's 110), so list keys never collide.
  void seedPositions(int count) {
    _positions.clear();

    _addOptionPositions(count);

    _emitPositions();
  }

  /// Bulk-adds [count] open NIFTY orders, skipping [placeOrder]'s fill and
  /// position pipeline.
  void seedOrders(int count) {
    final price = _dataSource.lastPrice;
    final productType = _defaultProductType('NIFTY');

    for (var i = 0; i < count; i++) {
      _orders.add(
        _order(
          symbolId: 'NIFTY',
          type: 'limit',
          action: i.isEven ? 'buy' : 'sell',
          productType: productType,
          avgPrice: price,
          price: price,
          qty: MockChartDataSource.lotSize,
          filled: 0,
          status: 'open',
        ),
      );
    }

    _emitOrders();
  }

  /// Bulk-adds [count] disabled NIFTY alerts. Disabled so they never
  /// trigger: a burst of trigger snackbars hangs pumpAndSettle.
  void seedAlerts(int count) {
    final price = _dataSource.lastPrice;

    for (var i = 0; i < count; i++) {
      _alertCounter++;

      _alerts.add(
        _alert(
          'ALERT${_alertCounter.toString().padLeft(3, '0')}',
          'NIFTY',
          (price + i).toStringAsFixed(2),
          enabled: false,
        ),
      );
    }

    _emitAlerts();
  }

  double _snapToTick(double raw) {
    const tickSize = MockChartDataSource.tickSize;

    return (raw / tickSize).round() * tickSize;
  }

  // ---------------------------------------------------------------------------
  // Stream emitters: the models' own factories parse each map.
  // ---------------------------------------------------------------------------

  void _emitOrders() {
    if (_disposed) return;

    _ordersController.add([for (final order in _orders) Order.fromJson(order)]);
  }

  void _emitPositions() {
    if (_disposed) return;

    _positionsController.add([
      for (final position in _positions) Position.fromMap(position),
    ]);
  }

  void _emitOcoOrders() {
    if (_disposed) return;

    _ocoOrdersController.add([
      for (final oco in _ocoOrders) OCOOrder.fromJson(oco),
    ]);
  }

  void _emitAlerts() {
    if (_disposed) return;

    _alertsController.add([for (final alert in _alerts) Alert.fromMap(alert)]);
  }

  void _feedback(ActionSentiment sentiment, String message) {
    if (_disposed) return;

    _feedbackController.add(
      ActionFeedback(sentiment: sentiment, message: message),
    );
  }
}
