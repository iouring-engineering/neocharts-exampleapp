import 'dart:math';

import 'package:neocharts_exampleapp/utils/formatting.dart';

/// Generates the synthetic NIFTY option-chain market data consumed by
/// [NxtChartRepository] (in `../repositories/nxt_chart_repository.dart`).
///
/// This is the app's mock "API" — everything here is fabricated (symbols,
/// candles, ticks, open interest). It knows nothing about orders, positions,
/// alerts or the streaming/interface glue that adapts it to the chart SDK;
/// that lives entirely in the repository.
class MockChartDataSource {
  MockChartDataSource() {
    optionChain = _generateOptionChain();

    allSymbols = [
      niftySymbol,
      ...optionChain,
      ...generateFutureSymbols(),
      ...generateIndexSymbols(),
    ];
  }

  static const double defaultSpotPrice = 22500.0;
  static const int lotSize = 65;
  static const double tickSize = 0.05;
  static const int precision = 2;

  static const List<int> _strikes = [
    22000,
    22050,
    22100,
    22150,
    22200,
    22250,
    22300,
    22350,
    22400,
    22450,
    22500,
    22550,
    22600,
    22650,
    22700,
    22750,
    22800,
    22850,
    22900,
    22950,
    23000,
    23050,
    23100,
    23150,
    23200,
    23250,
    23300,
    23350,
    23400,
    23450,
    23500,
    23550,
    23600,
    23650,
    23700,
  ];

  final Random _random = Random();

  double _lastPrice = defaultSpotPrice;

  double get lastPrice => _lastPrice;

  /// Latest emitted tick snapshot, refreshed by [generateTicks].
  final ticks = <Map<String, dynamic>>[];

  late final List<Map<String, dynamic>> optionChain;
  late final List<Map<String, dynamic>> allSymbols;

  // ---------------------------------------------------------------------------
  // Symbol generation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> get niftySymbol {
    return {
      'id': 'NIFTY',
      'name': 'NIFTY 50',
      'lotSize': lotSize,
      'precision': precision,
      'tickSize': tickSize,
      'exchange': 'NSE',
    };
  }

  List<Map<String, dynamic>> _generateOptionChain() {
    final expiry = nearestExpiry();
    final expiryId = _expiryId(expiry);

    final symbols = <Map<String, dynamic>>[];

    for (final strike in _strikes) {
      for (final type in ['CE', 'PE']) {
        symbols.add({
          'id': 'NIFTY$expiryId$strike$type',
          'name': 'NIFTY $strike $type $expiry',
          'precision': precision,
          'lotSize': lotSize,
          'tickSize': tickSize,
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

  List<Map<String, dynamic>> generateFutureSymbols() {
    final expiry = nearestExpiry();

    return [
      {
        'id': 'NIFTY${_expiryId(expiry)}FUT',
        'name': 'NIFTY FUT $expiry',
        'lotSize': lotSize,
        'precision': precision,
        'tickSize': tickSize,
        'expiry': expiry,
        'exchange': 'NSE',
      },
    ];
  }

  List<Map<String, dynamic>> generateIndexSymbols() {
    return [];
  }

  bool isFutureSymbol(String symbolId) {
    return generateFutureSymbols().any((future) {
      final futureId =
          future['symbolId']?.toString() ??
          future['symbol']?.toString() ??
          future['id']?.toString();

      return futureId == symbolId;
    });
  }

  Map<String, dynamic> symbolForId(String symbolId) {
    for (final symbol in allSymbols) {
      if (symbol['id'] == symbolId) {
        return symbol;
      }
    }

    return niftySymbol;
  }

  // ---------------------------------------------------------------------------
  // Historical bars
  // ---------------------------------------------------------------------------

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

    // Microseconds -> milliseconds
    if (value < 100000000000000000) {
      return value ~/ 1000;
    }

    // Nanoseconds -> milliseconds
    return value ~/ 1000000;
  }

  double initialPriceForSymbol(String symbolId) {
    if (symbolId == 'NIFTY') {
      return _lastPrice;
    }

    final option = optionChain.where((item) => item['id'] == symbolId);

    if (option.isNotEmpty) {
      final item = option.first;

      final strike = toDouble(item['strike']);

      final type = item['optType']?.toString();

      final intrinsic = type == 'CE'
          ? max(0, _lastPrice - strike)
          : max(0, strike - _lastPrice);

      final timeValue = 80 + _random.nextDouble() * 100;

      return max(5, intrinsic + timeValue);
    }

    return _lastPrice;
  }

  List<List<dynamic>> generateBars({
    required String symbolId,
    required int from,
    required int to,
    required int intervalSeconds,
    required int requiredBars,
  }) {
    final intervalMs = intervalSeconds * 1000 * 4;

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
    barCount = min(barCount, 5000);

    // Generate only HALF the number of bars.
    // Example:
    // 1000 -> 500
    // 500  -> 250
    // 101  -> 51
    barCount = max(1, (barCount / 2).ceil());

    final bars = <List<dynamic>>[];

    var price = initialPriceForSymbol(symbolId);

    // NIFTY and FUTURES limits.
    const marketMin = 22600.0;
    const marketMax = 22699.0;

    // Other symbols limits.
    const symbolMin = 200.0;
    const symbolMax = 300.0;

    // Maximum movement per candle.
    const maxMovement = 50.0;

    final isNifty = symbolId == 'NIFTY';
    final isMarketSymbol = isNifty || isFutureSymbol(symbolId);

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
          ? roundTo((open + change).clamp(marketMin, marketMax), precision)
          : roundTo((open + change).clamp(symbolMin, symbolMax), precision);

      final high = isMarketSymbol
          ? roundTo(
              (max(open, close) + _random.nextDouble() * maxMovement * 0.5)
                  .clamp(marketMin, marketMax),
              precision,
            )
          : roundTo(
              (max(open, close) + _random.nextDouble() * maxMovement * 0.5)
                  .clamp(symbolMin, symbolMax),
              precision,
            );

      final low = isMarketSymbol
          ? roundTo(
              (min(open, close) - _random.nextDouble() * maxMovement * 0.5)
                  .clamp(marketMin, marketMax),
              precision,
            )
          : roundTo(
              (min(open, close) - _random.nextDouble() * maxMovement * 0.5)
                  .clamp(symbolMin, symbolMax),
              precision,
            );

      final volume = 1000 + _random.nextInt(10000);

      bars.add([timestamp, roundTo(open, precision), high, low, close, volume]);

      // Next candle starts from previous candle's close.
      price = close;
    }

    return bars;
  }

  // ---------------------------------------------------------------------------
  // Live ticks
  // ---------------------------------------------------------------------------

  double _random3() =>
      double.parse(((_random.nextDouble() - 0.48) * 10).toStringAsFixed(3));

  List<Map<String, dynamic>> generateTicks() {
    ticks.clear();

    // Update NIFTY price.
    _lastPrice += (_random.nextDouble() - 0.48) * 10;
    _lastPrice = _lastPrice.clamp(22600.0, 22659.0);
    final niftyLtp = double.parse(_lastPrice.toStringAsFixed(2));

    // NIFTY / underlying tick.
    ticks.add({
      'symbolId': 'NIFTY',
      'ltp': niftyLtp,
      'ltq': 10 + _random.nextInt(90),
      'chng': roundTo(_lastPrice - defaultSpotPrice, precision),
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
    for (final option in optionChain) {
      final symbolId =
          option['symbolId']?.toString() ??
          option['symbol']?.toString() ??
          option['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        continue;
      }

      final currentLtp = toDouble(option['ltp']);
      // Maximum variation: -50 to +50 points.
      final optionMovement = _random.nextInt(101) - 50;

      var optionLtp = currentLtp + optionMovement;

      // Keep it within 100–250.
      optionLtp = 240 + toDouble((_random.nextInt(11)).toString()); // 240–250

      ticks.add({
        ...option,
        'symbolId': symbolId,
        'ltp': optionLtp,
        'ltq': 1 + _random.nextInt(99),
        'chng': roundTo(optionLtp - currentLtp, precision),
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
    for (final future in generateFutureSymbols()) {
      final symbolId =
          future['symbolId']?.toString() ??
          future['symbol']?.toString() ??
          future['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        continue;
      }

      final currentLtp = toDouble(future['ltp']);

      // Maximum variation: -50 to +50 points.
      _lastPrice += (_random.nextDouble() - 0.48) * 10;
      _lastPrice = _lastPrice.clamp(22600.0, 22659.0);
      final futureLtp = double.parse(_lastPrice.toStringAsFixed(2));

      ticks.add({
        ...future,
        'symbolId': symbolId,
        'ltp': futureLtp,
        'ltq': 10 + _random.nextInt(90),
        'chng': roundTo(futureLtp - currentLtp, precision),
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

    return ticks;
  }

  // ---------------------------------------------------------------------------
  // ATM / option-chain lookups
  // ---------------------------------------------------------------------------

  int nearestStrike(double price) {
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

  List<Map<String, dynamic>> atmOptions() {
    if (optionChain.isEmpty || _lastPrice <= 0) {
      return [];
    }

    final atmStrike = nearestStrike(_lastPrice);
    final expiry = nearestExpiry();

    final ce = optionChain.firstWhere(
      (option) =>
          toDouble(option['strike']) == toDouble(atmStrike) &&
          option['optType']?.toString().toUpperCase() == 'CE' &&
          option['expiry']?.toString() == expiry,
      orElse: () => <String, dynamic>{},
    );

    final pe = optionChain.firstWhere(
      (option) =>
          toDouble(option['strike']) == toDouble(atmStrike) &&
          option['optType']?.toString().toUpperCase() == 'PE' &&
          option['expiry']?.toString() == expiry,
      orElse: () => <String, dynamic>{},
    );

    final result = <Map<String, dynamic>>[];

    if (ce.isNotEmpty) {
      result.add(Map<String, dynamic>.from(ce));
    }

    if (pe.isNotEmpty) {
      result.add(Map<String, dynamic>.from(pe));
    }

    return result;
  }

  int mockVolume(Map<String, dynamic> option) {
    final strike = toInt(option['strike']) ?? nearestStrike(_lastPrice);

    final distance = (strike - nearestStrike(_lastPrice)).abs();

    return max(1000, 50000 - distance * 100 + _random.nextInt(20000));
  }

  List<Map<String, dynamic>> topOptionsByVolume({int limit = 10}) {
    final sorted = List<Map<String, dynamic>>.from(optionChain);

    sorted.sort((a, b) => mockVolume(b).compareTo(mockVolume(a)));

    return sorted.take(limit).map((option) {
      return {
        'symId': option['id'],
        'name': option['name'],
        'optType': option['optType'],
        'exchange': option['exchange'],
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Open interest
  // ---------------------------------------------------------------------------

  int generateOi(int strike, String type) {
    final distance = (strike - nearestStrike(_lastPrice)).abs();

    final base = max(10000, 100000 - distance * 50);

    final typeMultiplier = type == 'CE' ? 1.0 : 1.2;

    return (base * typeMultiplier).round() + _random.nextInt(25000);
  }

  int generateOiChange() {
    return _random.nextInt(50);
  }

  Map<String, dynamic> oiAnalysisAroundAtm() {
    final atm = nearestStrike(_lastPrice);

    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};

    for (var offset = -5; offset <= 5; offset++) {
      final strike = atm + (offset * 100);

      final callOi = generateOi(strike, 'CE');
      final putOi = generateOi(strike, 'PE');

      calls[strike.toString()] = {
        'oi': callOi,
        'oiChg': generateOiChange(),
        'prevOi': max(0, callOi - generateOiChange()),
      };

      puts[strike.toString()] = {
        'oi': putOi,
        'oiChg': generateOiChange(),
        'prevOi': max(0, putOi - generateOiChange()),
      };
    }

    return {'calls': calls, 'puts': puts};
  }

  Map<String, dynamic> oiChangeByStrike() {
    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};

    for (final strike in _strikes) {
      calls[strike.toString()] = generateOiChange();

      puts[strike.toString()] = generateOiChange();
    }

    return {'calls': calls, 'puts': puts};
  }

  Map<String, dynamic> oiByStrike() {
    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};

    for (final strike in _strikes) {
      calls[strike.toString()] = generateOi(strike, 'CE');

      puts[strike.toString()] = generateOi(strike, 'PE');
    }

    return {'calls': calls, 'puts': puts};
  }

  // ---------------------------------------------------------------------------
  // Intraday history (PCR / straddle / IV)
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> pcrIntradaySeries() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(hours: 4));
    const interval = Duration(minutes: 1);
    final rows = <Map<String, dynamic>>[];
    var price = _lastPrice;
    var pcr = 0.75;

    for (var time = from; !time.isAfter(now); time = time.add(interval)) {
      price = roundTo(
        (price + (_random.nextDouble() - 0.5) * 20).clamp(18000.0, 28000.0),
        precision,
      );
      pcr = (pcr + (_random.nextDouble() - 0.5) * 0.04).clamp(0.2, 1.8);
      rows.add({
        'time': time.millisecondsSinceEpoch,
        'price': price,
        'pcr': {
          '3': roundTo(pcr, 2),
          '5': roundTo(pcr * 1.05, 2),
          '10': roundTo(pcr * 0.95, 2),
          '20': roundTo(pcr * 1.10, 2),
          'all': roundTo(pcr, 2),
        },
      });
    }

    return rows;
  }

  Map<String, List<Map<String, dynamic>>> atmStraddleIntradaySeries() {
    final now = DateTime.now();

    final from = now.subtract(const Duration(hours: 4));

    const interval = Duration(minutes: 60);

    final candles = <Map<String, dynamic>>[];

    var straddle = 22600.0;

    for (var time = from; !time.isAfter(now); time = time.add(interval)) {
      straddle = (straddle + (_random.nextDouble() - 0.5) * 12).clamp(
        100.0,
        900.0,
      );

      candles.add({
        'time': time.millisecondsSinceEpoch,
        'atmStraddlePrice': 0.75,
      });
    }

    return {nearestExpiry(): candles};
  }

  List<Map<String, dynamic>> atmIvIntradaySeries() {
    final now = DateTime.now();

    final from = now.subtract(const Duration(hours: 4));

    const interval = Duration(minutes: 1);

    final candles = <Map<String, dynamic>>[];

    var iv = 20.0;

    for (var time = from; !time.isAfter(now); time = time.add(interval)) {
      iv = (iv + (_random.nextDouble() - 0.5) * 0.4).clamp(12.0, 35.0);

      candles.add({'time': time.millisecondsSinceEpoch, 'atmIv': 0.50});
    }

    return candles;
  }

  // ---------------------------------------------------------------------------
  // Expiry utilities
  // ---------------------------------------------------------------------------

  String nearestExpiry() {
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
}
