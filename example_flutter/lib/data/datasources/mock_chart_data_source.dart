import 'dart:math';

import 'package:neocharts_exampleapp/utils/formatting.dart';

/// NIFTY's live-tick band floor; other underlyings scale their bands off it.
const double _niftyBandLow = 22100.0;

/// An underlying with an option chain and one future. Its price bands are
/// NIFTY's, scaled by [scale].
class _Underlying {
  const _Underlying({
    required this.id,
    required this.name,
    required this.lotSize,
    required this.contractLotSize,
    required this.bandLow,
    required this.firstStrike,
    required this.strikeStep,
    required this.strikeCount,
  });

  final String id;
  final String name;
  final int lotSize;
  final int contractLotSize;
  final double bandLow;
  final int firstStrike;
  final int strikeStep;
  final int strikeCount;

  double get scale => bandLow / _niftyBandLow;

  List<int> get strikes => [
    for (var i = 0; i < strikeCount; i++) firstStrike + i * strikeStep,
  ];
}

enum _Kind { spot, future, option, other }

const _underlyings = [
  _Underlying(
    id: 'NIFTY',
    name: 'NIFTY 50',
    lotSize: MockChartDataSource.lotSize,
    contractLotSize: MockChartDataSource.lotSize,
    bandLow: _niftyBandLow,
    firstStrike: 22000,
    strikeStep: 50,
    strikeCount: 55,
  ),
  _Underlying(
    id: 'BANKNIFTY',
    name: 'BANKNIFTY',
    lotSize: 30,
    contractLotSize: 30,
    bandLow: 48200,
    firstStrike: 47250,
    strikeStep: 100,
    strikeCount: 21,
  ),
  _Underlying(
    id: 'RELIANCE',
    name: 'Reliance Industries',
    lotSize: 1,
    contractLotSize: 500,
    bandLow: 2930,
    firstStrike: 2800,
    strikeStep: 20,
    strikeCount: 15,
  ),
];

/// Generates the synthetic NIFTY, BANKNIFTY and RELIANCE market data
/// consumed by `NeoChartsRepository`.
///
/// This is the app's mock "API" — everything here is fabricated (symbols,
/// candles, ticks, open interest). It knows nothing about orders, positions,
/// alerts or the SDK contract; that lives entirely in the repository.
class MockChartDataSource {
  MockChartDataSource() {
    final expiry = nearestExpiry();

    for (final und in _underlyings) {
      _underlyingById[und.id] = und;
      _chains[und.id] = _generateOptionChain(und, expiry);
      _futures[und.id] = [_future(und, expiry)];
    }

    allSymbols = [
      for (final und in _underlyings) _spot(und),
      for (final und in _underlyings) ..._chains[und.id]!,
      for (final und in _underlyings) ..._futures[und.id]!,
      ...indexSymbols,
      ..._namedEquities(),
      ...generateEquitySymbols(),
    ];

    for (final symbol in allSymbols) {
      _byId[symbol['id'] as String] = symbol;
    }
  }

  final Map<String, double> _livePrices = {};
  final Map<String, double> _previousTickPrices = {};

  static const int lotSize = 65;
  static const double tickSize = 0.05;
  static const int precision = 2;

  final Random _random = Random();

  final Map<String, _Underlying> _underlyingById = {};
  final Map<String, List<Map<String, dynamic>>> _chains = {};
  final Map<String, List<Map<String, dynamic>>> _futures = {};
  final Map<String, Map<String, dynamic>> _byId = {};

  late final List<Map<String, dynamic>> allSymbols;

  /// Tracks the live NIFTY spot price as streamed ticks/bars update it.
  double get lastPrice => priceOf('NIFTY');

  /// [symbolId]'s last streamed or loaded price, else a plausible default.
  double priceOf(String symbolId) =>
      _livePrices[symbolId] ?? _defaultPrice(symbolId);

  double _defaultPrice(String symbolId) {
    final symbol = _byId[symbolId];
    final und = _underlyingOf(symbol);
    if (und == null) return 1000.0;

    return switch (_kindOf(symbol, und)) {
      _Kind.spot => und.bandLow + 500 * und.scale,
      _Kind.future => priceOf(und.id) + 10 * und.scale,
      _Kind.option => 117.5 * und.scale,
      _Kind.other => 1000.0,
    };
  }

  // ---------------------------------------------------------------------------
  // Symbol generation and lookup
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _spot(_Underlying und) {
    return {
      'id': und.id,
      'name': und.name,
      'lotSize': und.lotSize,
      'precision': precision,
      'tickSize': tickSize,
      'exchange': 'NSE',
      'segment': 'EQ',
    };
  }

  List<Map<String, dynamic>> _generateOptionChain(
    _Underlying und,
    String expiry,
  ) {
    final expiryId = _expiryId(expiry);

    return [
      for (final strike in und.strikes)
        for (final type in const ['CE', 'PE'])
          {
            'id': '${und.id}$expiryId$strike$type',
            'name': '${und.id} $strike $type $expiry',
            'precision': precision,
            'lotSize': und.contractLotSize,
            'tickSize': tickSize,
            'expiry': expiry,
            'exchange': 'NSE',
            'strike': strike.toString(),
            'optType': type,
            'weekly': 'N',
            'undID': und.id,
            'segment': 'OPT',
          },
    ];
  }

  Map<String, dynamic> _future(_Underlying und, String expiry) {
    return {
      'id': '${und.id}${_expiryId(expiry)}FUT',
      'name': '${und.id} FUT $expiry',
      'lotSize': und.contractLotSize,
      'precision': precision,
      'tickSize': tickSize,
      'expiry': expiry,
      'exchange': 'NSE',
      'undID': und.id,
      'segment': 'FUT',
    };
  }

  /// [underlyingId]'s option contracts; empty when it has none.
  List<Map<String, dynamic>> optionChain(String underlyingId) =>
      _chains[underlyingId] ?? const [];

  /// [underlyingId]'s futures; empty when it has none.
  List<Map<String, dynamic>> futures(String underlyingId) =>
      _futures[underlyingId] ?? const [];

  // NIFTY and BANKNIFTY are tradable here on purpose (patrol trades them);
  // the fixture apps treat them as indices.
  /// The one index with no option chain, to exercise the layout menu's FnO
  /// gating by switching to it.
  final List<Map<String, dynamic>> indexSymbols = const [
    {
      'id': 'INDIAVIX',
      'name': 'INDIA VIX',
      'lotSize': lotSize,
      'precision': precision,
      'tickSize': tickSize,
      'exchange': 'NSE',
      'segment': 'EQ',
    },
  ];

  List<Map<String, dynamic>> _namedEquities() {
    const names = {
      'TCS': 'Tata Consultancy Services',
      'INFY': 'Infosys',
      'HDFCBANK': 'HDFC Bank',
      'ICICIBANK': 'ICICI Bank',
    };

    return [
      for (final MapEntry(:key, :value) in names.entries)
        _equity(id: key, name: value),
    ];
  }

  Map<String, dynamic> _equity({required String id, required String name}) {
    return {
      'id': id,
      'name': name,
      'lotSize': 1,
      'precision': precision,
      'tickSize': tickSize,
      'exchange': 'NSE',
      'segment': 'EQ',
    };
  }

  /// Synthetic equity symbols that exist only to give the symbol-search
  /// panel a large, realistic universe to filter/scroll through.
  static const List<String> _equityNames = [
    'Reliance Industries',
    'Tata Consultancy Services',
    'HDFC Bank',
    'ICICI Bank',
    'Infosys',
    'Hindustan Unilever',
    'ITC',
    'State Bank of India',
    'Bharti Airtel',
    'Kotak Mahindra Bank',
    'Larsen & Toubro',
    'Axis Bank',
    'Bajaj Finance',
    'Maruti Suzuki',
    'Asian Paints',
    'HCL Technologies',
    'Titan Company',
    'Sun Pharmaceutical',
    'UltraTech Cement',
    'Wipro',
  ];

  List<Map<String, dynamic>> generateEquitySymbols({int count = 200}) {
    return List.generate(count, (i) {
      final base = _equityNames[i % _equityNames.length];
      final suffix = i ~/ _equityNames.length;
      final name = suffix == 0 ? base : '$base ${suffix + 1}';

      return _equity(id: 'EQ${(i + 1).toString().padLeft(4, '0')}', name: name);
    });
  }

  /// [symbolId]'s symbol, falling back to NIFTY for an unknown id.
  Map<String, dynamic> symbolForId(String symbolId) =>
      _byId[symbolId] ?? _byId['NIFTY']!;

  /// The underlying a symbol prices off (itself for a spot), if any.
  _Underlying? _underlyingOf(Map<String, dynamic>? symbol) =>
      _underlyingById[symbol?['undID'] ?? symbol?['id']];

  _Kind _kindOf(Map<String, dynamic>? symbol, _Underlying? und) {
    if (symbol == null || und == null) return _Kind.other;
    if (symbol['id'] == und.id) return _Kind.spot;

    return symbol['segment'] == 'OPT' ? _Kind.option : _Kind.future;
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

  /// `[timestamp, open, high, low, close, volume]` rows. Spots and futures
  /// converge into their tick band at the end, options into 110-120 (both
  /// scaled per underlying), so the last candle meets the live ticks.
  List<List<dynamic>> generateBars({
    required String symbolId,
    required int from,
    required int to,
    required int intervalSeconds,
    required int requiredBars,
  }) {
    final intervalMs = max(1, intervalSeconds) * 1000;

    final now = DateTime.now().millisecondsSinceEpoch;

    final actualFrom = from > 0
        ? _normalizeTimestamp(from)
        : now - const Duration(days: 5).inMilliseconds;

    final actualTo = to > 0 ? _normalizeTimestamp(to) : now;

    final safeFrom = min(actualFrom, actualTo);
    final safeTo = max(actualFrom, actualTo);

    var barCount = requiredBars > 0
        ? requiredBars
        : ((safeTo - safeFrom) ~/ intervalMs) + 1;

    // Cap at 50K
    barCount = max(1, min(barCount, 50000));

    var startTime = safeTo - ((barCount - 1) * intervalMs);

    if (startTime < safeFrom) {
      startTime = safeFrom;

      final availableBars = ((safeTo - startTime) ~/ intervalMs) + 1;

      barCount = min(barCount, availableBars);
    }

    final symbol = _byId[symbolId];
    final und = _underlyingOf(symbol);
    final kind = _kindOf(symbol, und);
    final s = und?.scale ?? 1.0;
    final bandLow = und?.bandLow ?? 0.0;

    final isMarket = kind == _Kind.spot || kind == _Kind.future;
    final isOption = kind == _Kind.option;

    final minPrice = isMarket ? bandLow - 100 * s : 1.0;
    final maxPrice = isMarket ? bandLow + 400 * s : 1000.0 * s;

    // A future with no history starts at the spot plus a small basis; an
    // option at a plausible premium, converging later.
    var price =
        _livePrices[symbolId] ??
        switch (kind) {
          _Kind.future =>
            priceOf(und!.id) + (5 + _random.nextDouble() * 15) * s,
          _Kind.option => (80 + _random.nextDouble() * 35) * s,
          _ => priceOf(symbolId),
        };

    price = roundTo(price.clamp(minPrice, maxPrice).toDouble(), precision);

    final maxMovement = (isMarket ? 25.0 : (isOption ? 8.0 : 5.0)) * s;

    final targetMin = isMarket ? bandLow : 110 * s;
    final targetMax = isMarket ? bandLow + 100 * s : 120 * s;

    const convergenceBars = 20;

    final bars = <List<dynamic>>[];

    for (var i = 0; i < barCount; i++) {
      final timestamp = startTime + (i * intervalMs);

      final barsRemaining = barCount - 1 - i;

      final open = price;

      var closePrice = open + (_random.nextDouble() - 0.5) * (maxMovement * 2);

      if (barsRemaining < convergenceBars) {
        final convergence =
            ((convergenceBars - barsRemaining) / convergenceBars).clamp(
              0.0,
              1.0,
            );

        if (isMarket) {
          closePrice = _convergeMarket(
            closePrice,
            convergence: convergence,
            barsRemaining: barsRemaining,
            targetMin: targetMin,
            targetMax: targetMax,
            scale: s,
          );
        } else if (isOption) {
          closePrice = _convergeOption(
            closePrice,
            convergence: convergence,
            barsRemaining: barsRemaining,
            targetMin: targetMin,
            targetMax: targetMax,
            scale: s,
          );
        }
      }

      final close = roundTo(
        closePrice.clamp(minPrice, maxPrice).toDouble(),
        precision,
      );

      final upperWick = _random.nextDouble() * (maxMovement * 0.5);

      final lowerWick = _random.nextDouble() * (maxMovement * 0.5);

      var highPrice = max(open, close) + upperWick;

      var lowPrice = min(open, close) - lowerWick;

      // Keep the final candles' wicks near the target band.
      if ((isMarket || isOption) && barsRemaining <= 10) {
        final wickRoom = (isMarket ? 15.0 : 8.0) * s;

        highPrice = min(highPrice, targetMax + wickRoom);

        lowPrice = max(lowPrice, targetMin - wickRoom);
      }

      final high = roundTo(
        highPrice.clamp(minPrice, maxPrice).toDouble(),
        precision,
      );

      final low = roundTo(
        lowPrice.clamp(minPrice, maxPrice).toDouble(),
        precision,
      );

      final volume = 1000 + _random.nextInt(10000);

      bars.add([timestamp, roundTo(open, precision), high, low, close, volume]);

      price = close;
    }

    // Save the last historical close for streaming.
    if (bars.isNotEmpty) {
      _livePrices[symbolId] = toDouble(bars.last[4]);
    }

    return bars;
  }

  // Pulls a spot/future close into the target band over the last 20 bars,
  // clamping tighter over the final 10.
  double _convergeMarket(
    double closePrice, {
    required double convergence,
    required int barsRemaining,
    required double targetMin,
    required double targetMax,
    required double scale,
  }) {
    var close = closePrice;

    final targetPrice =
        targetMin + _random.nextDouble() * (targetMax - targetMin);

    close += (targetPrice - close) * convergence * 0.65;

    close += (_random.nextDouble() - 0.5) * 20.0 * scale * (1.0 - convergence);

    if (barsRemaining <= 10) {
      final finalPhase = ((10 - barsRemaining) / 10.0).clamp(0.0, 1.0);

      final allowedOutsideRange = 10.0 * scale * (1.0 - finalPhase);

      close = close.clamp(
        targetMin - allowedOutsideRange,
        targetMax + allowedOutsideRange,
      );

      if (finalPhase > 0.5) {
        final finalTarget =
            targetMin + _random.nextDouble() * (targetMax - targetMin);

        close += (finalTarget - close) * finalPhase * 0.6;
      }
    }

    return close;
  }

  // Pulls an option close into the target band over the last 20 bars, with
  // an upward bias over the final 10 and a tight clamp over the final 5.
  double _convergeOption(
    double closePrice, {
    required double convergence,
    required int barsRemaining,
    required double targetMin,
    required double targetMax,
    required double scale,
  }) {
    var close = closePrice;

    final targetPrice =
        targetMin + _random.nextDouble() * (targetMax - targetMin);

    var pullStrength = convergence * 0.45;

    if (barsRemaining <= 10) {
      final finalPhase = ((10 - barsRemaining) / 10.0).clamp(0.0, 1.0);

      // Starts around 0.45 and increases toward 0.90.
      pullStrength = 0.45 + (finalPhase * 0.45);
    }

    close += (targetPrice - close) * pullStrength;

    if (barsRemaining <= 10) {
      final finalPhase = ((10 - barsRemaining) / 10.0).clamp(0.0, 1.0);

      close += (1.5 + (finalPhase * 3.0)) * scale;

      close += (_random.nextDouble() - 0.5) * 2.0 * scale * (1.0 - finalPhase);
    }

    if (barsRemaining <= 5) {
      final finalPhase = ((5 - barsRemaining) / 5.0).clamp(0.0, 1.0);

      final finalTarget =
          targetMin + _random.nextDouble() * (targetMax - targetMin);

      close += (finalTarget - close) * (0.65 + finalPhase * 0.25);

      final allowedOutside = 5.0 * scale * (1.0 - finalPhase);

      close = close.clamp(
        targetMin - allowedOutside,
        targetMax + allowedOutside,
      );
    }

    return close;
  }

  // ---------------------------------------------------------------------------
  // Live ticks
  // ---------------------------------------------------------------------------

  double _random3() =>
      double.parse(((_random.nextDouble() - 0.48) * 10).toStringAsFixed(3));

  /// One tick per known id in [symbolIds]; unknown ids are skipped.
  List<Map<String, dynamic>> generateTicks(Iterable<String> symbolIds) {
    final now = DateTime.now().millisecondsSinceEpoch;

    return [
      for (final id in symbolIds)
        if (_byId[id] case final symbol?) _tick(symbol, now),
    ];
  }

  // Spots and futures walk +-2 inside a 50-wide band, options +-1 inside
  // 110-125 (NIFTY's numbers, scaled); anything else drifts freely.
  Map<String, dynamic> _tick(Map<String, dynamic> symbol, int now) {
    final id = symbol['id'] as String;
    final und = _underlyingOf(symbol);
    final kind = _kindOf(symbol, und);
    final s = und?.scale ?? 1.0;

    final band = switch (kind) {
      _Kind.spot || _Kind.future => (und!.bandLow, und.bandLow + 50 * s),
      _Kind.option => (110 * s, 125 * s),
      _Kind.other => null,
    };

    var price = _livePrices[id];

    if (band != null && (price == null || price < band.$1 || price > band.$2)) {
      price = band.$1 + _random.nextDouble() * (band.$2 - band.$1);
    }

    price ??= priceOf(id);

    final step = switch (kind) {
      _Kind.option => 2.0 * s,
      _Kind.other => price * 0.001,
      _ => 4.0 * s,
    };

    price += (_random.nextDouble() - 0.5) * step;

    if (band != null) price = price.clamp(band.$1, band.$2);

    price = roundTo(price, precision);

    _livePrices[id] = price;

    final previous = _previousTickPrices[id] ?? price;

    final change = roundTo(price - previous, precision);

    final changePer = previous != 0
        ? roundTo((change / previous) * 100, 2)
        : 0.0;

    _previousTickPrices[id] = price;

    final common = {
      'symbolId': id,
      'ltp': price,
      'dayClose': price,
      'chng': change,
      'chngPer': changePer,
      'ltt': now,
      'oiChngPer': (_random.nextDouble() - 0.5) * 2,
      'delta': _random3(),
      'gamma': _random3(),
      'theta': _random3(),
      'vega': _random3(),
    };

    if (kind != _Kind.option) {
      return {
        if (kind == _Kind.future) ...symbol,
        ...common,
        'ltq': 10 + _random.nextInt(90),
        'oi': _random3(),
        'volume': _random3(),
      };
    }

    return {
      ...symbol,
      ...common,
      'ltq': 1 + _random.nextInt(99),
      'oiChng': _random3(),
      'OI': _random3(),
      'vwap': price,
      'vol': _random3(),
      'itm': _random.nextBool().toString(),
      'iv': _random3(),
      'rho': _random3(),
      'highIV': _random3(),
      'lowIV': _random3(),
    };
  }

  // ---------------------------------------------------------------------------
  // ATM / option-chain lookups
  // ---------------------------------------------------------------------------

  int _nearestStrike(_Underlying und) {
    final price = priceOf(und.id);

    return und.strikes.reduce(
      (a, b) => (price - b).abs() < (price - a).abs() ? b : a,
    );
  }

  /// [underlyingId]'s most active options by mock volume, busiest first.
  List<Map<String, dynamic>> topOptions(String underlyingId, {int limit = 10}) {
    final und = _underlyingById[underlyingId];
    if (und == null) return const [];

    final atm = _nearestStrike(und);

    final ranked = [
      for (final option in optionChain(underlyingId))
        (
          option: option,
          volume: max(
            1000,
            50000 -
                (toInt(option['strike'])! - atm).abs() ~/
                    und.strikeStep *
                    5000 +
                _random.nextInt(20000),
          ),
        ),
    ]..sort((a, b) => b.volume.compareTo(a.volume));

    return [for (final row in ranked.take(limit)) row.option];
  }

  // ---------------------------------------------------------------------------
  // Open interest
  // ---------------------------------------------------------------------------

  int _oi(_Underlying und, int atm, int strike, String type) {
    final distance = (strike - atm).abs() / und.strikeStep;

    final base = max(10000, 100000 - distance * 2500);

    final typeMultiplier = type == 'CE' ? 1.0 : 1.2;

    return (base * typeMultiplier).round() + _random.nextInt(25000);
  }

  int _oiChange() => _random.nextInt(50);

  /// `{calls, puts}` of `{strike: {oi, oiChg, prevOi}}` for 5 strikes
  /// either side of ATM, two strike steps apart.
  Map<String, dynamic> oiAnalysisAroundAtm(String underlyingId) {
    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};
    final und = _underlyingById[underlyingId];

    if (und != null) {
      final atm = _nearestStrike(und);

      for (var offset = -5; offset <= 5; offset++) {
        final strike = atm + (offset * 2 * und.strikeStep);

        final callOi = _oi(und, atm, strike, 'CE');
        final putOi = _oi(und, atm, strike, 'PE');

        calls[strike.toString()] = {
          'oi': callOi,
          'oiChg': _oiChange(),
          'prevOi': max(0, callOi - _oiChange()),
        };

        puts[strike.toString()] = {
          'oi': putOi,
          'oiChg': _oiChange(),
          'prevOi': max(0, putOi - _oiChange()),
        };
      }
    }

    return {'calls': calls, 'puts': puts};
  }

  /// `{calls, puts}` of `{strike: oiChange}` over every chain strike.
  Map<String, dynamic> oiChangeByStrike(String underlyingId) =>
      _byStrike(underlyingId, (und, atm, strike, type) => _oiChange());

  /// `{calls, puts}` of `{strike: oi}` over every chain strike.
  Map<String, dynamic> oiByStrike(String underlyingId) =>
      _byStrike(underlyingId, _oi);

  Map<String, dynamic> _byStrike(
    String underlyingId,
    int Function(_Underlying und, int atm, int strike, String type) value,
  ) {
    final calls = <String, dynamic>{};
    final puts = <String, dynamic>{};
    final und = _underlyingById[underlyingId];

    if (und != null) {
      final atm = _nearestStrike(und);

      for (final strike in und.strikes) {
        calls[strike.toString()] = value(und, atm, strike, 'CE');

        puts[strike.toString()] = value(und, atm, strike, 'PE');
      }
    }

    return {'calls': calls, 'puts': puts};
  }

  // ---------------------------------------------------------------------------
  // Intraday history (PCR / straddle / IV)
  // ---------------------------------------------------------------------------

  Iterable<DateTime> _intraday(Duration interval) sync* {
    final now = DateTime.now();

    for (
      var time = now.subtract(const Duration(hours: 4));
      !time.isAfter(now);
      time = time.add(interval)
    ) {
      yield time;
    }
  }

  List<Map<String, dynamic>> pcrIntradaySeries(String underlyingId) {
    final und = _underlyingById[underlyingId];
    if (und == null) return const [];

    final s = und.scale;
    final rows = <Map<String, dynamic>>[];
    var price = priceOf(und.id);
    var pcr = 0.75;

    for (final time in _intraday(const Duration(minutes: 1))) {
      price = roundTo(
        (price + (_random.nextDouble() - 0.5) * 20 * s).clamp(
          18000.0 * s,
          28000.0 * s,
        ),
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

  Map<String, List<Map<String, dynamic>>> atmStraddleIntradaySeries(
    String underlyingId,
  ) {
    final und = _underlyingById[underlyingId];
    if (und == null) return const {};

    final s = und.scale;
    final candles = <Map<String, dynamic>>[];
    var straddle = 900.0 * s;

    for (final time in _intraday(const Duration(minutes: 60))) {
      straddle = (straddle + (_random.nextDouble() - 0.5) * 12 * s).clamp(
        100.0 * s,
        900.0 * s,
      );

      candles.add({
        'time': time.millisecondsSinceEpoch,
        'atmStraddlePrice': roundTo(straddle, precision),
      });
    }

    return {nearestExpiry(): candles};
  }

  List<Map<String, dynamic>> atmIvIntradaySeries(String underlyingId) {
    if (!_underlyingById.containsKey(underlyingId)) return const [];

    final candles = <Map<String, dynamic>>[];
    var iv = 20.0;

    for (final time in _intraday(const Duration(minutes: 1))) {
      iv = (iv + (_random.nextDouble() - 0.5) * 0.4).clamp(12.0, 35.0);

      candles.add({
        'time': time.millisecondsSinceEpoch,
        'atmIv': roundTo(iv, 2),
      });
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
