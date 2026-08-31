import 'dart:async';
import 'dart:convert';

import 'package:neocharts_exampleapp/data/datasources/mock_chart_data_source.dart';
import 'package:neocharts_exampleapp/data/datasources/stream_rate.dart';
import 'package:neocharts_exampleapp/utils/formatting.dart';
import 'package:nxtchart/interface.dart';

export 'package:neocharts_exampleapp/data/datasources/stream_rate.dart';

/// Adapts [MockChartDataSource] (the mock market-data "API") to the chart
/// SDK's [ChartInterface] contract.
///
/// Owns everything the SDK contract requires that isn't pure market data:
/// order/position/alert/OCO state, the broadcast streams the chart
/// subscribes to, and the JSON (de)serialization at the edge of that
/// contract. Market-data generation itself is delegated to
/// [MockChartDataSource].
class NxtChartRepository implements ChartInterface {
  NxtChartRepository({
    required this.storageKey,
    this.streamRate = StreamRate.r1,
    this.liveDataEnabled = true,
  }) {
    _initialize();
  }

  @override
  final String storageKey;

  final StreamRate streamRate;
  final bool liveDataEnabled;

  final MockChartDataSource _dataSource = MockChartDataSource();

  // ---------------------------------------------------------------------------
  // Local trading state
  // ---------------------------------------------------------------------------

  Timer? _streamTimer;

  final StreamController<String> _marketDataController =
      StreamController<String>.broadcast();

  final StreamController<String> _ordersController =
      StreamController<String>.broadcast();

  final StreamController<String> _positionsController =
      StreamController<String>.broadcast();

  final StreamController<String> _ocoOrdersController =
      StreamController<String>.broadcast();

  final StreamController<String> _alertsController =
      StreamController<String>.broadcast();

  final StreamController<String> _feedbackController =
      StreamController<String>.broadcast();

  final StreamController<({String keyword, String resultsJson})>
  _searchController =
      StreamController<({String keyword, String resultsJson})>.broadcast();

  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _positions = [];
  final List<Map<String, dynamic>> _ocoOrders = [];
  final List<Map<String, dynamic>> _alerts = [];

  int _orderCounter = 0;
  int _ocoCounter = 0;
  int _alertCounter = 0;

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  void _initialize() {
    _emitOrders();
    _emitPositions();
    _emitOcoOrders();
    _emitAlerts();

    if (liveDataEnabled) {
      _startStreaming();
    }
  }

  // ---------------------------------------------------------------------------
  // ChartInterface
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _streamTimer?.cancel();
    _streamTimer = null;

    _marketDataController.close();
    _ordersController.close();
    _positionsController.close();
    _ocoOrdersController.close();
    _alertsController.close();
    _feedbackController.close();
    _searchController.close();
  }

  @override
  ChartInterface? chartInterfaceForSymbol(String symbolJson) {
    try {
      final symbol = jsonDecode(symbolJson);

      if (symbol is! Map<String, dynamic>) {
        return null;
      }

      final symbolId = symbol['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        return null;
      }

      return NxtChartRepository(
        storageKey: '$storageKey:$symbolId',
        streamRate: streamRate,
        liveDataEnabled: liveDataEnabled,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // MarketDataInterface
  // ---------------------------------------------------------------------------

  @override
  String get symbolInfo {
    return jsonEncode(_dataSource.niftySymbol);
  }

  @override
  String? get underlyingSymbolInfo {
    return jsonEncode(_dataSource.niftySymbol);
  }

  @override
  String get optionSymbols {
    return jsonEncode(_dataSource.optionChain);
  }

  @override
  String? get futureSymbols {
    return jsonEncode(_dataSource.generateFutureSymbols());
  }

  @override
  String? get indexSymbols {
    return jsonEncode(_dataSource.generateIndexSymbols());
  }

  @override
  String get marketTiming {
    return jsonEncode({
      'timezone': 'Asia/Kolkata',
      'sessions': List.generate(7, (_) => ['0000-2359']),
      'holidays': <String>[],
      'special': <String, dynamic>{},
    });
  }

  @override
  Future<String> get chartTopOptions async {
    return jsonEncode(_dataSource.topOptionsByVolume());
  }

  @override
  Future<String> loadData({
    required String symbolId,
    required int from,
    required int to,
    required int intervalSeconds,
    required int requiredBars,
  }) async {
    final bars = _dataSource.generateBars(
      symbolId: symbolId,
      from: from,
      to: to,
      intervalSeconds: intervalSeconds,
      requiredBars: requiredBars,
    );

    return jsonEncode(bars);
  }

  @override
  Future<String?> get atmSymbols async {
    final result = _dataSource.atmOptions();

    return result.isEmpty ? null : jsonEncode(result);
  }

  @override
  Stream<String> marketDataStreamer(String symbols) {
    return _marketDataController.stream;
  }

  @override
  Stream<String> searchSymbolsStreamer(String query) {
    final keyword = query.trim().toLowerCase();

    scheduleMicrotask(() {
      if (_disposed) {
        return;
      }

      if (keyword.isEmpty) {
        _searchController.add((
          keyword: keyword,
          resultsJson: jsonEncode(_dataSource.allSymbols),
        ));

        return;
      }

      final results = _dataSource.allSymbols.where((symbol) {
        final id = (symbol['id'] ?? '').toString().toLowerCase();

        final name = (symbol['name'] ?? '').toString().toLowerCase();

        return id.contains(keyword) || name.contains(keyword);
      }).toList();

      _searchController.add((
        keyword: keyword,
        resultsJson: jsonEncode(results),
      ));
    });

    return _searchController.stream
        .where((event) => event.keyword == keyword)
        .map((event) => event.resultsJson);
  }

  @override
  Future<String> fetchOptionDetails({
    required String underlyingSymbolId,
  }) async {
    return jsonEncode([_dataSource.niftySymbol, ..._dataSource.optionChain]);
  }

  @override
  Future<String?> fetchOIAnalysis({
    required String underlyingSymbolId,
    required String expiry,
    required int timeFrom,
    required int timeTo,
  }) async {
    return jsonEncode(_dataSource.oiAnalysisAroundAtm());
  }

  @override
  Future<String?> fetchOIChange({
    required String underlyingSymbolId,
    required List<String> expiries,
    required int timeFrom,
    required int timeTo,
  }) async {
    return jsonEncode(_dataSource.oiChangeByStrike());
  }

  @override
  Future<String?> fetchOI({
    required String underlyingSymbolId,
    required List<String> expiries,
  }) async {
    return jsonEncode(_dataSource.oiByStrike());
  }

  @override
  Future<String> fetchPcrIntraday() async {
    return jsonEncode(_dataSource.pcrIntradaySeries());
  }

  @override
  Future<String> fetchAtmStraddleIntraday() async {
    return jsonEncode(_dataSource.atmStraddleIntradaySeries());
  }

  @override
  Future<String> fetchAtmIvIntraday() async {
    return jsonEncode(_dataSource.atmIvIntradaySeries());
  }

  // ---------------------------------------------------------------------------
  // TradeInterface
  // ---------------------------------------------------------------------------

  @override
  bool get hasOCO => true;

  @override
  Stream<String> get ordersStreamer {
    return _ordersController.stream;
  }

  @override
  Stream<String> get positionsStreamer {
    return _positionsController.stream;
  }

  @override
  Stream<String> get ocoOrdersStreamer {
    return _ocoOrdersController.stream;
  }

  @override
  Stream<String> get actionFeedbackStreamer {
    return _feedbackController.stream;
  }

  @override
  Stream<String> get alertsStreamer {
    return _alertsController.stream;
  }

  @override
  void placeOrder(String params) {
    try {
      final data = jsonDecode(params) as Map<String, dynamic>;

      _orderCounter++;

      final symbolId = data['symID']?.toString() ?? 'NIFTY';

      final price = toDouble(data['price']);

      final qty = toInt(data['qty']) ?? MockChartDataSource.lotSize;

      final orderType = data['orderType']?.toString() ?? 'limit';

      final orderAction = data['orderAction']?.toString() ?? 'buy';

      final productType = data['productType']?.toString() ?? 'normal';

      /// this should be handled from Orders api since aren't using any apis we are hard coding the ltp
      final ticks = _dataSource.ticks;
      final index = ticks.indexWhere((ele) => ele['id'] == symbolId);
      final ltp = toInt(ticks[index]['ltp']);

      final order = {
        'orderID': 'ORD${_orderCounter.toString().padLeft(3, '0')}',
        'type': orderType,
        'orderAction': orderAction,
        'productType': productType,
        'avgPrice': price,
        'price': orderType == 'market' ? ltp : price,
        'netQty': qty,
        'fillQty': 0,
        'ordTime': formatDateTime(DateTime.now()),
        'orderStatus': 'open',
        'triggerPrice': data['triggerPrice'] ?? 0,
        'symbol': _dataSource.symbolForId(symbolId),
      };

      _orders.add(order);

      _emitOrders();

      _feedback(
        type: 'positive',
        message: 'Order ${order['orderID']} placed successfully',
      );
    } catch (_) {
      _feedback(type: 'negative', message: 'Failed to place order');
    }
  }

  @override
  void modifyOrder(String params) {
    try {
      final data = jsonDecode(params) as Map<String, dynamic>;

      final orderId = data['orderID']?.toString();

      if (orderId == null) {
        return;
      }

      final index = _orders.indexWhere((order) => order['orderID'] == orderId);

      if (index == -1) {
        _feedback(type: 'negative', message: 'Order not found');

        return;
      }

      final existing = _orders[index];

      if (data.containsKey('price')) {
        existing['price'] = data['price'];
        existing['avgPrice'] = data['price'];
      }

      if (data.containsKey('qty')) {
        existing['netQty'] = data['qty'];
      }

      if (data.containsKey('orderType')) {
        existing['type'] = data['orderType'];
      }

      if (data.containsKey('orderAction')) {
        existing['orderAction'] = data['orderAction'];
      }

      if (data.containsKey('productType')) {
        existing['productType'] = data['productType'];
      }

      if (data.containsKey('triggerPrice')) {
        existing['triggerPrice'] = data['triggerPrice'];
      }

      _emitOrders();

      _feedback(type: 'positive', message: 'Order $orderId modified');
    } catch (_) {
      _feedback(type: 'negative', message: 'Failed to modify order');
    }
  }

  @override
  void cancelOrder(String orderID) {
    final index = _orders.indexWhere((order) => order['orderID'] == orderID);

    if (index == -1) {
      _feedback(type: 'negative', message: 'Order not found');

      return;
    }

    _orders[index]['orderStatus'] = 'cancelled';

    _emitOrders();

    _feedback(type: 'negative', message: 'Order $orderID cancelled');
  }

  @override
  void placeOCOOrder(String params) {
    try {
      final data = jsonDecode(params) as Map<String, dynamic>;

      _ocoCounter++;

      final groupId =
          data['groupId']?.toString() ??
          'OCO${_ocoCounter.toString().padLeft(3, '0')}';

      final symbolId = data['symID']?.toString() ?? 'NIFTY';

      final lastPrice = _dataSource.lastPrice;

      final oco = {
        'groupId': groupId,
        'symID': symbolId,
        'name': _dataSource.symbolForId(symbolId)['name'],
        'exchange': 'NSE',
        'side': data['side']?.toString() ?? 'sell',
        'productType': data['productType']?.toString() ?? 'normal',
        'stopLoss': {
          'type': 'stopLoss',
          'side': data['side']?.toString() ?? 'sell',
          'triggerPrice': data['stopPrice'] ?? lastPrice,
          'qty': data['stopQty'] ?? MockChartDataSource.lotSize,
          'price': data['stopPrice'] ?? lastPrice,
          'fillQty': 0,
        },
        'target': {
          'type': 'limit',
          'side': data['side']?.toString() ?? 'sell',
          'triggerPrice':
              data['targetTriggerPrice'] ?? data['targetPrice'] ?? lastPrice,
          'qty': data['targetQty'] ?? MockChartDataSource.lotSize,
          'price': data['targetPrice'] ?? lastPrice,
          'fillQty': 0,
        },
      };

      _ocoOrders.add(oco);

      _emitOcoOrders();

      _feedback(type: 'positive', message: 'OCO $groupId created');
    } catch (_) {
      _feedback(type: 'negative', message: 'Failed to create OCO');
    }
  }

  @override
  void modifyOCOOrder(String params) {
    try {
      final data = jsonDecode(params) as Map<String, dynamic>;

      final groupId = data['groupId']?.toString();

      if (groupId == null) {
        return;
      }

      final index = _ocoOrders.indexWhere((oco) => oco['groupId'] == groupId);

      if (index == -1) {
        _feedback(type: 'negative', message: 'OCO not found');

        return;
      }

      final oco = _ocoOrders[index];

      if (data.containsKey('stopPrice')) {
        final stopLoss = oco['stopLoss'] as Map<String, dynamic>;

        stopLoss['triggerPrice'] = data['stopPrice'];

        stopLoss['price'] = data['stopPrice'];
      }

      if (data.containsKey('targetPrice')) {
        final target = oco['target'] as Map<String, dynamic>;

        target['price'] = data['targetPrice'];
      }

      if (data.containsKey('targetTriggerPrice')) {
        final target = oco['target'] as Map<String, dynamic>;

        target['triggerPrice'] = data['targetTriggerPrice'];
      }

      _emitOcoOrders();

      _feedback(type: 'positive', message: 'OCO $groupId modified');
    } catch (_) {
      _feedback(type: 'negative', message: 'Failed to modify OCO');
    }
  }

  @override
  void cancelOCOOrder(String groupId) {
    _emitOcoOrders();

    _feedback(type: 'negative', message: 'OCO $groupId cancelled');
  }

  @override
  void groupAdjustOrders(String params) {
    try {
      final data = jsonDecode(params) as Map<String, dynamic>;

      final exit = data['exit'] as List<dynamic>? ?? [];

      final add = data['add'] as List<dynamic>? ?? [];

      final lastPrice = _dataSource.lastPrice;

      for (final item in exit) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final symbolId = item['id']?.toString() ?? 'NIFTY';

        final qty = toInt(item['quantity']) ?? MockChartDataSource.lotSize;

        final action = item['action']?.toString() ?? 'Sell';

        _positions.removeWhere((position) => position['symID'] == symbolId);

        _orders.add({
          'orderID': 'ORD${(++_orderCounter).toString().padLeft(3, '0')}',
          'type': item['ordType'] ?? 'market',
          'orderAction': action.toLowerCase(),
          'productType': 'normal',
          'avgPrice': item['price'] ?? lastPrice,
          'price': 245,
          'netQty': qty,
          'fillQty': qty,
          'ordTime': DateTime.now().toIso8601String(),
          'orderStatus': 'completed',
          'triggerPrice': 0,
          'symbol': _dataSource.symbolForId(symbolId),
        });
      }

      for (final item in add) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final symbolId = item['id']?.toString() ?? 'NIFTY';

        final qty = toInt(item['quantity']) ?? MockChartDataSource.lotSize;

        final action = item['action']?.toString() ?? 'Buy';

        _orders.add({
          'orderID': 'ORD${(++_orderCounter).toString().padLeft(3, '0')}',
          'type': item['ordType'] ?? 'market',
          'orderAction': action.toLowerCase(),
          'productType': 'normal',
          'avgPrice': item['price'] ?? lastPrice,
          'price': item['price'] ?? lastPrice,
          'netQty': qty,
          'fillQty': qty,
          'ordTime': DateTime.now().toIso8601String(),
          'orderStatus': 'completed',
          'triggerPrice': 0,
          'symbol': _dataSource.symbolForId(symbolId),
        });

        _upsertPosition(
          symbolId: symbolId,
          quantity: action.toLowerCase() == 'buy' ? qty : -qty,
          price: toDouble(item['price']),
        );
      }

      _emitOrders();
      _emitPositions();

      _feedback(type: 'positive', message: 'Group orders adjusted');
    } catch (_) {
      _feedback(type: 'negative', message: 'Failed to adjust group orders');
    }
  }

  @override
  void modifyAlert(String params) {
    try {
      final data = jsonDecode(params) as Map<String, dynamic>;

      final alertId = data['alertId']?.toString();

      if (alertId == null) {
        return;
      }

      final index = _alerts.indexWhere((alert) => alert['alertId'] == alertId);

      if (index == -1) {
        return;
      }

      if (data.containsKey('triggerPrice')) {
        _alerts[index]['triggerPrice'] = data['triggerPrice'].toString();
      }

      _emitAlerts();

      _feedback(type: 'positive', message: 'Alert $alertId modified');
    } catch (_) {
      _feedback(type: 'negative', message: 'Failed to modify alert');
    }
  }

  @override
  void createAlert(String params) {
    try {
      final data = jsonDecode(params) as Map<String, dynamic>;

      _alertCounter++;

      final symbolId = data['symbolId']?.toString() ?? 'NIFTY';

      final alert = {
        'alertId': 'ALERT${_alertCounter.toString().padLeft(3, '0')}',
        'symbolInfo': _dataSource.symbolForId(symbolId),
        'triggerPrice':
            data['triggerPrice']?.toString() ??
            _dataSource.lastPrice.toStringAsFixed(2),
        'enabled': true,
        'triggered': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      _alerts.add(alert);

      _emitAlerts();

      _feedback(type: 'positive', message: 'Alert ${alert['alertId']} created');
    } catch (_) {
      _feedback(type: 'negative', message: 'Failed to create alert');
    }
  }

  @override
  void deleteAlert(String alertId) {
    _alerts.removeWhere((alert) => alert['alertId'] == alertId);

    _emitAlerts();

    _feedback(type: 'negative', message: 'Alert $alertId deleted');
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
    final ticks = _dataSource.generateTicks();

    _marketDataController.add(jsonEncode(ticks));
  }

  // ---------------------------------------------------------------------------
  // Position handling
  // ---------------------------------------------------------------------------

  void _upsertPosition({
    required String symbolId,
    required int quantity,
    required double price,
  }) {
    final index = _positions.indexWhere(
      (position) =>
          position['symID'] == symbolId && position['productType'] == 'normal',
    );

    if (index == -1) {
      _positions.add(
        _createPosition(symbolId: symbolId, quantity: quantity, price: price),
      );

      return;
    }

    final position = _positions[index];

    final oldQty = toInt(position['netQty']) ?? 0;

    final newQty = oldQty + quantity;

    position['netQty'] = newQty;
    position['avgPrice'] = price;
    position['netOrgAvgPrice'] = price;

    if (newQty == 0) {
      _positions.removeAt(index);
    }
  }

  Map<String, dynamic> _createPosition({
    required String symbolId,
    required int quantity,
    required double price,
  }) {
    return {
      'symID': symbolId,
      'displayName': _dataSource.symbolForId(symbolId)['name'],
      'netQty': quantity,
      'avgPrice': price,
      'netOrgAvgPrice': price,
      'pnl': 0.0,
      'realizedPnl': 0.0,
      'realizedOrgPnl': 0.0,
      'unrealizedPL': 0.0,
      'mtm': 0.0,
      'multiplier': 1.0,
      'priceFactor': 1.0,
      'productType': 'normal',
      'symbol': _dataSource.symbolForId(symbolId),
    };
  }

  void _updatePositions() {
    final lastPrice = _dataSource.lastPrice;

    for (final position in _positions) {
      final qty = toInt(position['netQty']) ?? 0;

      final avgPrice = toDouble(position['avgPrice']);

      final pnl = (lastPrice - avgPrice) * qty;

      position['pnl'] = roundTo(pnl, 2);

      position['unrealizedPL'] = roundTo(pnl, 2);

      position['mtm'] = roundTo(pnl, 2);
    }

    _emitPositions();
  }

  // ---------------------------------------------------------------------------
  // Alert handling
  // ---------------------------------------------------------------------------

  void _evaluateAlerts() {
    var changed = false;

    final lastPrice = _dataSource.lastPrice;

    for (final alert in _alerts) {
      if (alert['enabled'] != true || alert['triggered'] == true) {
        continue;
      }

      final trigger = double.tryParse(alert['triggerPrice']?.toString() ?? '');

      if (trigger == null) {
        continue;
      }

      final difference = (lastPrice - trigger).abs();

      if (difference <= 2.0) {
        alert['triggered'] = true;
        changed = true;

        _feedback(
          type: 'positive',
          message: 'Alert ${alert['alertId']} triggered',
        );
      }
    }

    if (changed) {
      _emitAlerts();
    }
  }

  // ---------------------------------------------------------------------------
  // OCO handling
  // ---------------------------------------------------------------------------

  void _evaluateOcoOrders() {
    final triggered = <String>[];

    final lastPrice = _dataSource.lastPrice;

    for (final oco in _ocoOrders) {
      final groupId = oco['groupId']?.toString();

      if (groupId == null) {
        continue;
      }

      final stopLoss = oco['stopLoss'] as Map<String, dynamic>;

      final target = oco['target'] as Map<String, dynamic>;

      final stopPrice = toDouble(stopLoss['triggerPrice']);

      final targetPrice = toDouble(target['triggerPrice']);

      if (lastPrice <= stopPrice) {
        triggered.add(groupId);
        continue;
      }

      if (lastPrice >= targetPrice) {
        triggered.add(groupId);
      }
    }

    for (final groupId in triggered) {
      _ocoOrders.removeWhere((oco) => oco['groupId'] == groupId);

      _feedback(type: 'positive', message: 'OCO $groupId triggered');
    }

    if (triggered.isNotEmpty) {
      _emitOcoOrders();
    }
  }

  // ---------------------------------------------------------------------------
  // Stream emitters
  // ---------------------------------------------------------------------------

  void _emitOrders() {
    if (_disposed) {
      return;
    }

    _ordersController.add(jsonEncode(_orders));
  }

  void _emitPositions() {
    if (_disposed) {
      return;
    }

    final optionChain = _dataSource.optionChain;

    if (optionChain.isEmpty) {
      return;
    }

    // Pick a few actual options from the option chain.
    final selectedOptions = optionChain.take(6).toList();

    final positions = <Map<String, dynamic>>[];

    for (var i = 0; i < selectedOptions.length; i++) {
      final option = selectedOptions[i];

      final symbolId =
          option['symbolId']?.toString() ??
          option['symbol']?.toString() ??
          option['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        continue;
      }

      // Use the option's current LTP if available.
      final currentPrice = toDouble(option['ltp']);

      // Long for some positions, short for others.
      final netQty = i.isEven ? 50 : -25;

      // Average entry price slightly different from current price.
      final avgPrice = (currentPrice + (i.isEven ? -5 : 5)).clamp(100.0, 300.0);

      final pnl = netQty > 0
          ? (currentPrice - avgPrice) * netQty
          : (avgPrice - currentPrice) * netQty.abs();

      positions.add({
        'symID': symbolId,
        'displayName': option['name']?.toString() ?? symbolId,
        'netQty': netQty,
        'avgPrice': 245,
        'netOrgAvgPrice': 245,
        'pnl': pnl,
        'realizedPnl': 0.0,
        'realizedOrgPnl': 0.0,
        'unrealizedPL': pnl,
        'mtm': pnl,
        'multiplier': 1.0,
        'priceFactor': 1.0,
        'productType': i.isEven ? 'normal' : 'intraday',

        // Send the actual option-chain symbol.
        'symbol': option,
      });
    }

    _positionsController.add(jsonEncode(positions));
  }

  void _emitOcoOrders() {
    if (_disposed) {
      return;
    }

    _ocoOrdersController.add(jsonEncode(_ocoOrders));
  }

  void _emitAlerts() {
    if (_disposed) {
      return;
    }

    _alertsController.add(jsonEncode(_alerts));
  }

  void _feedback({required String type, required String message}) {
    if (_disposed) {
      return;
    }

    _feedbackController.add(jsonEncode({'type': type, 'message': message}));
  }
}
