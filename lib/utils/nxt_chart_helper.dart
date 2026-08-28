import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:nxtchart/interface.dart';

class NxtChartHelper implements ChartInterface {
  NxtChartHelper({
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

  final Random _random = Random();

  // ---------------------------------------------------------------------------
  // Local state
  // ---------------------------------------------------------------------------

  static const double _defaultSpotPrice = 22500.0;
  static const int _lotSize = 65;
  static const double _tickSize = 0.05;
  static const int _precision = 2;

  double _lastPrice = _defaultSpotPrice;

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
  // Local symbol universe
  // ---------------------------------------------------------------------------

  static const List<int> _strikes = [
    22600,
    22601,
    22602,
    22603,
    22604,
    22605,
    22606,
    22607,
    22608,
    22609,
    22610,
    22611,
    22612,
    22613,
    22614,
    22615,
    22616,
    22617,
    22618,
    22619,
    22620,
    22621,
    22622,
    22623,
    22624,
    22625,
    22626,
    22627,
    22628,
    22629,
    22630,
    22631,
    22632,
    22633,
    22634,
    22635,
    22636,
    22637,
  ];

  late final List<Map<String, dynamic>> _optionChain;

  late final List<Map<String, dynamic>> _allSymbols;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  void _initialize() {
    _optionChain = _generateOptionChain();

    _allSymbols = [
      _niftySymbol(),
      ..._optionChain,
      ..._generateFutureSymbols(),
      ..._generateIndexSymbols(),
    ];

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

      return NxtChartHelper(
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
    return jsonEncode(_niftySymbol());
  }

  @override
  String? get underlyingSymbolInfo {
    return jsonEncode(_niftySymbol());
  }

  @override
  String get optionSymbols {
    return jsonEncode(_optionChain);
  }

  @override
  String? get futureSymbols {
    return jsonEncode(_generateFutureSymbols());
  }

  @override
  String? get indexSymbols {
    return jsonEncode(_generateIndexSymbols());
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
    final sorted = List<Map<String, dynamic>>.from(_optionChain);

    sorted.sort((a, b) => _mockVolume(b).compareTo(_mockVolume(a)));

    final top = sorted.take(10).map((option) {
      return {
        'symId': option['id'],
        'name': option['name'],
        'optType': option['optType'],
        'exchange': option['exchange'],
      };
    }).toList();

    return jsonEncode(top);
  }

  int _normalizeTimestamp(int value) {
    if (value <= 0) {
      return 0;
    }

    // Seconds -> milliseconds
    if (value < 100000000000) {
      return value * 1000;
    }

    // Already milliseconds
    if (value < 100000000000000) {
      return value;
    }

    // Microseconds -> millisecondsx
    if (value < 100000000000000000) {
      return value ~/ 1000;
    }

    // Nanoseconds -> milliseconds
    return value ~/ 1000000;
  }

  @override
  Future<String> loadData({
    required String symbolId,
    required int from,
    required int to,
    required int intervalSeconds,
    required int requiredBars,
  }) async {
    final intervalMs = intervalSeconds * 1000;

    // Normalize timestamps because the API may provide
    // seconds, milliseconds, microseconds, or nanoseconds.
    final actualFrom = from > 0
        ? _normalizeTimestamp(from)
        : DateTime.now()
              .subtract(const Duration(days: 5))
              .millisecondsSinceEpoch;

    final actualTo = to > 0
        ? _normalizeTimestamp(to)
        : DateTime.now().millisecondsSinceEpoch;

    // Make sure the range is valid.
    final safeFrom = min(actualFrom, actualTo);
    final safeTo = max(actualFrom, actualTo);

    var barCount = ((safeTo - safeFrom) / intervalMs).floor() + 1;

    if (barCount <= 0) {
      barCount = requiredBars > 0 ? requiredBars : 100;
    }

    if (requiredBars > 0) {
      barCount = min(barCount, requiredBars);
    }

    // Avoid creating an enormous list.
    barCount = min(barCount, 50000);

    final bars = <List<dynamic>>[];

    var price = _initialPriceForSymbol(symbolId);

    // NIFTY and FUTURES limits.
    const marketMin = 22600.0;
    const marketMax = 22699.0;

    // Other symbols limits.
    const symbolMin = 200.0;
    const symbolMax = 300.0;

    // Maximum movement per candle.
    const maxMovement = 50.0;

    // NIFTY.
    final isNifty = symbolId == 'NIFTY';

    // FUTURES.
    final isFuture = _generateFutureSymbols().any((future) {
      final futureId =
          future['symbolId']?.toString() ??
          future['symbol']?.toString() ??
          future['id']?.toString();

      return futureId == symbolId;
    });

    final isMarketSymbol = isNifty || isFuture;

    // Keep initial price inside the correct range.
    if (isMarketSymbol) {
      price = price.clamp(marketMin, marketMax);
    } else {
      price = price.clamp(symbolMin, symbolMax);
    }

    final startTime = safeTo - ((barCount - 1) * intervalMs);

    for (var i = 0; i < barCount; i++) {
      final timestamp = startTime + (i * intervalMs);

      final open = price;

      // Maximum movement = +/- 50 points.
      final change = (_random.nextDouble() - 0.5) * (maxMovement * 2);

      final close = isMarketSymbol
          ? _roundPrice((open + change).clamp(marketMin, marketMax))
          : _roundPrice((open + change).clamp(symbolMin, symbolMax));

      final high = isMarketSymbol
          ? _roundPrice(
              (max(open, close) + _random.nextDouble() * maxMovement * 0.5)
                  .clamp(marketMin, marketMax),
            )
          : _roundPrice(
              (max(open, close) + _random.nextDouble() * maxMovement * 0.5)
                  .clamp(symbolMin, symbolMax),
            );

      final low = isMarketSymbol
          ? _roundPrice(
              (min(open, close) - _random.nextDouble() * maxMovement * 0.5)
                  .clamp(marketMin, marketMax),
            )
          : _roundPrice(
              (min(open, close) - _random.nextDouble() * maxMovement * 0.5)
                  .clamp(symbolMin, symbolMax),
            );

      final volume = 1000 + _random.nextInt(10000);

      bars.add([timestamp, _roundPrice(open), high, low, close, volume]);

      // Next candle starts from previous candle's close.
      price = close;
    }

    return jsonEncode(bars);
  }

  @override
  Future<String?> get atmSymbols async {
    if (_optionChain.isEmpty || _lastPrice <= 0) {
      return null;
    }

    final atmStrike = _nearestStrike(_lastPrice);
    final expiry = _nearestExpiry();

    final ce = _optionChain.firstWhere(
      (option) =>
          _toDouble(option['strike']) == _toDouble(atmStrike) &&
          option['optType']?.toString().toUpperCase() == 'CE' &&
          option['expiry']?.toString() == expiry.toString(),
      orElse: () => <String, dynamic>{},
    );

    final pe = _optionChain.firstWhere(
      (option) =>
          _toDouble(option['strike']) == _toDouble(atmStrike) &&
          option['optType']?.toString().toUpperCase() == 'PE' &&
          option['expiry']?.toString() == expiry.toString(),
      orElse: () => <String, dynamic>{},
    );

    final result = <Map<String, dynamic>>[];

    if (ce.isNotEmpty) {
      result.add(Map<String, dynamic>.from(ce));
    }

    if (pe.isNotEmpty) {
      result.add(Map<String, dynamic>.from(pe));
    }

    if (result.isEmpty) {
      return null;
    }

    return jsonEncode(result);
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
          resultsJson: jsonEncode(_allSymbols),
        ));

        return;
      }

      final results = _allSymbols.where((symbol) {
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
    final underlying = _niftySymbol();

    return jsonEncode([underlying, ..._optionChain]);
  }

  @override
  Future<String?> fetchOIAnalysis({
    required String underlyingSymbolId,
    required String expiry,
    required int timeFrom,
    required int timeTo,
  }) async {
    final atm = _nearestStrike(_lastPrice);

    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};

    for (var offset = -5; offset <= 5; offset++) {
      final strike = atm + (offset * 100);

      final callOi = _generateOi(strike, 'CE');
      final putOi = _generateOi(strike, 'PE');

      calls[strike.toString()] = {
        'oi': callOi,
        'oiChg': _generateOiChange(),
        'prevOi': max(0, callOi - _generateOiChange()),
      };

      puts[strike.toString()] = {
        'oi': putOi,
        'oiChg': _generateOiChange(),
        'prevOi': max(0, putOi - _generateOiChange()),
      };
    }

    return jsonEncode({'calls': calls, 'puts': puts});
  }

  @override
  Future<String?> fetchOIChange({
    required String underlyingSymbolId,
    required List<String> expiries,
    required int timeFrom,
    required int timeTo,
  }) async {
    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};

    for (final strike in _strikes) {
      calls[strike.toString()] = _generateOiChange();

      puts[strike.toString()] = _generateOiChange();
    }

    return jsonEncode({'calls': calls, 'puts': puts});
  }

  @override
  Future<String?> fetchOI({
    required String underlyingSymbolId,
    required List<String> expiries,
  }) async {
    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};

    for (final strike in _strikes) {
      calls[strike.toString()] = _generateOi(strike, 'CE');

      puts[strike.toString()] = _generateOi(strike, 'PE');
    }

    return jsonEncode({'calls': calls, 'puts': puts});
  }

  @override
  Future<String> fetchPcrIntraday() async {
    final now = DateTime.now();

    final from = now.subtract(const Duration(hours: 4));

    const interval = Duration(minutes: 1);

    final rows = <Map<String, dynamic>>[];

    var price = _lastPrice;
    var pcr = 0.75;

    for (var time = from; !time.isAfter(now); time = time.add(interval)) {
      price = _roundPrice(
        (price + (_random.nextDouble() - 0.5) * 20).clamp(18000.0, 28000.0),
      );

      pcr = (pcr + (_random.nextDouble() - 0.5) * 0.04).clamp(0.2, 1.8);

      rows.add({
        'time': time.millisecondsSinceEpoch,
        'price': price,
        'pcr': {
          '3': _round(pcr, 2),
          '5': _round(pcr * 1.05, 2),
          '10': _round(pcr * 0.95, 2),
          '20': _round(pcr * 1.10, 2),
          'all': _round(pcr, 2),
        },
      });
    }

    return jsonEncode(rows);
  }

  @override
  Future<String> fetchAtmStraddleIntraday() async {
    final now = DateTime.now();

    final from = now.subtract(const Duration(hours: 4));

    const interval = Duration(minutes: 1);

    final candles = <Map<String, dynamic>>[];

    var straddle = 420.0;

    for (var time = from; !time.isAfter(now); time = time.add(interval)) {
      straddle = (straddle + (_random.nextDouble() - 0.5) * 12).clamp(
        100.0,
        900.0,
      );

      candles.add({
        'time': time.millisecondsSinceEpoch,
        'atmStraddlePrice': _round(straddle, 2),
      });
    }

    return jsonEncode({_nearestExpiry(): candles});
  }

  @override
  Future<String> fetchAtmIvIntraday() async {
    final now = DateTime.now();

    final from = now.subtract(const Duration(hours: 4));

    const interval = Duration(minutes: 1);

    final candles = <Map<String, dynamic>>[];

    var iv = 20.0;

    for (var time = from; !time.isAfter(now); time = time.add(interval)) {
      iv = (iv + (_random.nextDouble() - 0.5) * 0.4).clamp(12.0, 35.0);

      candles.add({
        'time': time.millisecondsSinceEpoch,
        'atmIv': _round(iv, 2),
      });
    }

    return jsonEncode(candles);
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

      final price = _toDouble(data['price']);

      final qty = _toInt(data['qty']) ?? _lotSize;

      final orderType = data['orderType']?.toString() ?? 'limit';

      final orderAction = data['orderAction']?.toString() ?? 'buy';

      final productType = data['productType']?.toString() ?? 'normal';

      final order = {
        'orderID': 'ORD${_orderCounter.toString().padLeft(3, '0')}',
        'type': orderType,
        'orderAction': orderAction,
        'productType': productType,
        'avgPrice': price,
        'price': price,
        'netQty': qty,
        'fillQty': 0,
        'ordTime': _formatDateTime(DateTime.now()),
        'orderStatus': 'open',
        'triggerPrice': data['triggerPrice'] ?? 0,
        'symbol': _symbolForId(symbolId),
      };

      _orders.add(order);

      _emitOrders();

      _feedback(
        type: 'positive',
        message: 'Order ${order['orderID']} placed successfully',
      );
    } catch (e) {
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

      final oco = {
        'groupId': groupId,
        'symID': symbolId,
        'name': _symbolForId(symbolId)['name'],
        'exchange': 'NSE',
        'side': data['side']?.toString() ?? 'sell',
        'productType': data['productType']?.toString() ?? 'normal',
        'stopLoss': {
          'type': 'stopLoss',
          'side': data['side']?.toString() ?? 'sell',
          'triggerPrice': data['stopPrice'] ?? _lastPrice,
          'qty': data['stopQty'] ?? _lotSize,
          'price': data['stopPrice'] ?? _lastPrice,
          'fillQty': 0,
        },
        'target': {
          'type': 'limit',
          'side': data['side']?.toString() ?? 'sell',
          'triggerPrice':
              data['targetTriggerPrice'] ?? data['targetPrice'] ?? _lastPrice,
          'qty': data['targetQty'] ?? _lotSize,
          'price': data['targetPrice'] ?? _lastPrice,
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

      for (final item in exit) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final symbolId = item['id']?.toString() ?? 'NIFTY';

        final qty = _toInt(item['quantity']) ?? _lotSize;

        final action = item['action']?.toString() ?? 'Sell';

        _positions.removeWhere((position) => position['symID'] == symbolId);

        _orders.add({
          'orderID': 'ORD${(++_orderCounter).toString().padLeft(3, '0')}',
          'type': item['ordType'] ?? 'market',
          'orderAction': action.toLowerCase(),
          'productType': 'normal',
          'avgPrice': item['price'] ?? _lastPrice,
          'price': 245,
          'netQty': qty,
          'fillQty': qty,
          'ordTime': DateTime.now().toIso8601String(),
          'orderStatus': 'completed',
          'triggerPrice': 0,
          'symbol': _symbolForId(symbolId),
        });
      }

      for (final item in add) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final symbolId = item['id']?.toString() ?? 'NIFTY';

        final qty = _toInt(item['quantity']) ?? _lotSize;

        final action = item['action']?.toString() ?? 'Buy';

        _orders.add({
          'orderID': 'ORD${(++_orderCounter).toString().padLeft(3, '0')}',
          'type': item['ordType'] ?? 'market',
          'orderAction': action.toLowerCase(),
          'productType': 'normal',
          'avgPrice': item['price'] ?? _lastPrice,
          'price': item['price'] ?? _lastPrice,
          'netQty': qty,
          'fillQty': qty,
          'ordTime': DateTime.now().toIso8601String(),
          'orderStatus': 'completed',
          'triggerPrice': 0,
          'symbol': _symbolForId(symbolId),
        });

        _upsertPosition(
          symbolId: symbolId,
          quantity: action.toLowerCase() == 'buy' ? qty : -qty,
          price: _toDouble(item['price']),
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
        'symbolInfo': _symbolForId(symbolId),
        'triggerPrice':
            data['triggerPrice']?.toString() ?? _lastPrice.toStringAsFixed(2),
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
    // Update NIFTY price.
    _lastPrice += (_random.nextDouble() - 0.48) * 10;
    _lastPrice = _lastPrice.clamp(22600.0, 22659.0);
    final ltp = double.parse(_lastPrice.toStringAsFixed(2));
    final ticks = <Map<String, dynamic>>[];

    // NIFTY / underlying tick.
    ticks.add({
      'symbolId': 'NIFTY',
      'ltp': ltp,
      'ltq': 10 + _random.nextInt(90),
      'chng': _roundPrice(_lastPrice - _defaultSpotPrice),
      'chngPer': (_random.nextDouble() - 0.48) * 10,
      'ltt': DateTime.now().millisecondsSinceEpoch,
      'oiChngPer': (_random.nextDouble() - 0.48) * 10,
      'oi': (_random.nextDouble() - 0.48) * 10,
      'volume': _random3(),
      'delta': _random3(),
      'gamma': _random3(),
      'theta': _random3(),
      'vega': _random3(),
    });

    // Stream every option in the option chain.
    for (final option in _optionChain) {
      final symbolId =
          option['symbolId']?.toString() ??
          option['symbol']?.toString() ??
          option['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        continue;
      }

      final currentLtp = _toDouble(option['ltp']);
      // Maximum variation: -50 to +50 points.
      final optionMovement = _random.nextInt(101) - 50;

      var ltp = currentLtp + optionMovement;

      // Keep it within 100–250.

      ltp = 240 + _toDouble((_random.nextInt(11)).toString()); // 240–250

      ticks.add({
        ...option,
        'symbolId': symbolId,
        'ltp': ltp,
        'ltq': 1 + _random.nextInt(99),
        'chng': _roundPrice(ltp - currentLtp),
        'chngPer': (_random.nextDouble() - 0.48) * 10,
        'ltt': DateTime.now().millisecondsSinceEpoch,
        'oiChngPer': (_random.nextDouble() - 0.48) * 10,
        'OI': _random3(),
        'vWap': _random3(),
        'vol': _random3(),
        'delta': _random3(),
        'gamma': _random3(),
        'theta': _random3(),
        'vega': _random3(),
      });
    }

    // Add future ticks
    for (final future in _generateFutureSymbols()) {
      final symbolId =
          future['symbolId']?.toString() ??
          future['symbol']?.toString() ??
          future['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        continue;
      }

      final currentLtp = _toDouble(future['ltp']);

      // Maximum variation: -50 to +50 points.
      _lastPrice += (_random.nextDouble() - 0.48) * 10;
      _lastPrice = _lastPrice.clamp(22600.0, 22659.0);
      final ltp = double.parse(_lastPrice.toStringAsFixed(2));
      ticks.add({
        ...future,
        'symbolId': symbolId,
        'ltp': ltp,
        'ltq': 10 + _random.nextInt(90),
        'chng': _roundPrice(ltp - currentLtp),
        'chngPer': (_random.nextDouble() - 0.48) * 10,
        'ltt': DateTime.now().millisecondsSinceEpoch,
        'oiChngPer': (_random.nextDouble() - 0.48) * 10,
        'oi': (_random.nextDouble() - 0.48) * 10,
        'volume': _random3(),
        'delta': _random3(),
        'gamma': _random3(),
        'theta': _random3(),
        'vega': _random3(),
      });
    }

    // Emit EVERYTHING in one update.
    _marketDataController.add(jsonEncode(ticks));
  }

  double _random3() =>
      double.parse(((_random.nextDouble() - 0.48) * 10).toStringAsFixed(3));
  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
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

    final oldQty = _toInt(position['netQty']) ?? 0;

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
      'displayName': _symbolForId(symbolId)['name'],
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
      'symbol': _symbolForId(symbolId),
    };
  }

  void _updatePositions() {
    for (final position in _positions) {
      final qty = _toInt(position['netQty']) ?? 0;

      final avgPrice = _toDouble(position['avgPrice']);

      final pnl = (_lastPrice - avgPrice) * qty;

      position['pnl'] = _round(pnl, 2);

      position['unrealizedPL'] = _round(pnl, 2);

      position['mtm'] = _round(pnl, 2);
    }

    _emitPositions();
  }

  // ---------------------------------------------------------------------------
  // Alert handling
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

      final difference = (_lastPrice - trigger).abs();

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

    for (final oco in _ocoOrders) {
      final groupId = oco['groupId']?.toString();

      if (groupId == null) {
        continue;
      }

      final stopLoss = oco['stopLoss'] as Map<String, dynamic>;

      final target = oco['target'] as Map<String, dynamic>;

      final stopPrice = _toDouble(stopLoss['triggerPrice']);

      final targetPrice = _toDouble(target['triggerPrice']);

      if (_lastPrice <= stopPrice) {
        triggered.add(groupId);
        continue;
      }

      if (_lastPrice >= targetPrice) {
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

    if (_optionChain.isEmpty) {
      return;
    }

    final options = List<Map<String, dynamic>>.from(_optionChain);

    // Pick a few actual options from the option chain.
    final selectedOptions = options.take(6).toList();

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
      final currentPrice = _toDouble(option['ltp']);

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

  // ---------------------------------------------------------------------------
  // Symbol generation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _niftySymbol() {
    return {
      'id': 'NIFTY',
      'name': 'NIFTY 50',
      'lotSize': _lotSize,
      'precision': _precision,
      'tickSize': _tickSize,
      'exchange': 'NSE',
    };
  }

  List<Map<String, dynamic>> _generateOptionChain() {
    final expiry = _nearestExpiry();
    final expiryId = _expiryId(expiry);

    final symbols = <Map<String, dynamic>>[];

    for (final strike in _strikes) {
      for (final type in ['CE', 'PE']) {
        symbols.add({
          'id': 'NIFTY$expiryId$strike$type',
          'name': 'NIFTY $strike $type $expiry',
          'precision': _precision,
          'lotSize': _lotSize,
          'tickSize': _tickSize,
          'expiry': expiry,
          'exchange': 'NSE',
          'strike': strike.toString(),
          'optType': type,
          'weekly': 'N',
        });
      }
    }

    return symbols;
  }

  List<Map<String, dynamic>> _generateFutureSymbols() {
    final expiry = _nearestExpiry();

    return [
      {
        'id': 'NIFTY${_expiryId(expiry)}FUT',
        'name': 'NIFTY FUT $expiry',
        'lotSize': _lotSize,
        'precision': _precision,
        'tickSize': _tickSize,
        'expiry': expiry,
        'exchange': 'NSE',
      },
    ];
  }

  List<Map<String, dynamic>> _generateIndexSymbols() {
    return [];
  }

  // ---------------------------------------------------------------------------
  // Symbol utilities
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _symbolForId(String symbolId) {
    for (final symbol in _allSymbols) {
      if (symbol['id'] == symbolId) {
        return symbol;
      }
    }

    return _niftySymbol();
  }

  double _initialPriceForSymbol(String symbolId) {
    if (symbolId == 'NIFTY') {
      return _lastPrice;
    }

    final option = _optionChain.where((item) => item['id'] == symbolId);

    if (option.isNotEmpty) {
      final item = option.first;

      final strike = _toDouble(item['strike']);

      final type = item['optType']?.toString();

      final intrinsic = type == 'CE'
          ? max(0, _lastPrice - strike)
          : max(0, strike - _lastPrice);

      final timeValue = 80 + _random.nextDouble() * 100;

      return max(5, intrinsic + timeValue);
    }

    return _lastPrice;
  }

  // ---------------------------------------------------------------------------
  // Option / OI utilities
  // ---------------------------------------------------------------------------

  int _nearestStrike(double price) {
    var nearest = _strikes.first;
    var distance = (price - nearest).abs();

    for (final strike in _strikes) {
      final currentDistance = (price - strike).abs();

      if (currentDistance < distance) {
        nearest = strike;
        distance = currentDistance;
      }
    }

    return nearest;
  }

  int _generateOi(int strike, String type) {
    final distance = (strike - _nearestStrike(_lastPrice)).abs();

    final base = max(10000, 100000 - distance * 50);

    final typeMultiplier = type == 'CE' ? 1.0 : 1.2;

    return (base * typeMultiplier).round() + _random.nextInt(25000);
  }

  int _generateOiChange() {
    return _random.nextInt(50);
  }

  int _mockVolume(Map<String, dynamic> option) {
    final strike = _toInt(option['strike']) ?? _nearestStrike(_lastPrice);

    final distance = (strike - _nearestStrike(_lastPrice)).abs();

    return max(1000, 50000 - distance * 100 + _random.nextInt(20000));
  }

  // ---------------------------------------------------------------------------
  // Expiry utilities
  // ---------------------------------------------------------------------------

  String _nearestExpiry() {
    var date = DateTime.now();

    while (date.weekday != DateTime.thursday) {
      date = date.add(const Duration(days: 1));
    }

    return _formatDate(date);
  }

  String _expiryId(String expiry) {
    final parts = expiry.split('-');

    if (parts.length != 3) {
      return 'EXP';
    }

    final year = int.tryParse(parts[0]) ?? 0;

    final month = int.tryParse(parts[1]) ?? 1;

    final day = int.tryParse(parts[2]) ?? 1;

    return '${day.toString().padLeft(2, '0')}'
        '${_monthCode(month)}'
        '${year % 100}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _monthCode(int month) {
    const codes = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return codes[month - 1];
  }

  // ---------------------------------------------------------------------------
  // Numeric utilities
  // ---------------------------------------------------------------------------

  double _roundPrice(double value) {
    return double.parse(value.toStringAsFixed(_precision));
  }

  double _round(double value, int decimals) {
    return double.parse(value.toStringAsFixed(decimals));
  }

  String _formatDateTime(DateTime dateTime) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(dateTime.day)}-'
        '${twoDigits(dateTime.month)}-'
        '${dateTime.year} '
        '${twoDigits(dateTime.hour)}:'
        '${twoDigits(dateTime.minute)}:'
        '${twoDigits(dateTime.second)}';
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }
}

/// Local configuration enums.
///
/// Keep these only if the example app does not already
/// define StreamRate elsewhere.

enum StreamRate { r1, r10, r30 }

extension StreamRateX on StreamRate {
  int get perSecond {
    switch (this) {
      case StreamRate.r1:
        return 1;
      case StreamRate.r10:
        return 10;
      case StreamRate.r30:
        return 30;
    }
  }

  Duration get interval {
    return Duration(milliseconds: 500);
  }
}
