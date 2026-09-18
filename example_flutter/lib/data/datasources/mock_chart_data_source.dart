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
  double _niftyLivePrice = 22600.0;

  final Map<String, double> _livePrices = {};
  final Map<String, double> _previousTickPrices = {};

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

  /// Tracks the live NIFTY spot price as streamed ticks/bars update it.
  double get lastPrice => _livePrices['NIFTY'] ?? _niftyLivePrice;

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
    return [
      // The one index in this fixture with no option chain -- lets the
      // chart layout menu's FnO gating be exercised by actually switching
      // to it (see NxtChartRepository.chartInterfaceForSymbol).
      {
        'id': 'INDIAVIX',
        'name': 'INDIA VIX',
        'lotSize': lotSize,
        'precision': precision,
        'tickSize': tickSize,
        'exchange': 'NSE',
      },
    ];
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
      return lastPrice;
    }

    final option = optionChain.where((item) => item['id'] == symbolId);

    if (option.isNotEmpty) {
      final item = option.first;

      final strike = toDouble(item['strike']);

      final type = item['optType']?.toString();

      final intrinsic = type == 'CE'
          ? max(0, lastPrice - strike)
          : max(0, strike - lastPrice);

      final timeValue = 80 + _random.nextDouble() * 100;

      return max(5, intrinsic + timeValue);
    }

    return lastPrice;
  }

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

    // ------------------------------------------------------------
    // Bar count
    // ------------------------------------------------------------

    int barCount;

    if (requiredBars > 0) {
      barCount = requiredBars;
    } else {
      barCount = ((safeTo - safeFrom) ~/ intervalMs) + 1;
    }

    // Cap at 50K
    barCount = max(1, min(barCount, 50000));

    // ------------------------------------------------------------
    // Start time
    // ------------------------------------------------------------

    var startTime = safeTo - ((barCount - 1) * intervalMs);

    if (startTime < safeFrom) {
      startTime = safeFrom;

      final availableBars = ((safeTo - startTime) ~/ intervalMs) + 1;

      barCount = min(barCount, availableBars);
    }

    // ------------------------------------------------------------
    // Instrument type
    // ------------------------------------------------------------

    final upperSymbol = symbolId.toUpperCase();

    final isSpot = upperSymbol == 'NIFTY';

    final isFuture = isFutureSymbol(symbolId);

    // ------------------------------------------------------------
    // OPTIONS DETECTION
    //
    // Adjust this if your option symbol format is different.
    //
    // Examples:
    // NIFTY24SEP22100CE
    // NIFTY24SEP22100PE
    // NIFTY-22100-CE
    // NIFTY22100CE
    // ------------------------------------------------------------

    final isCallOption =
        upperSymbol.endsWith('CE') || upperSymbol.contains('CE');

    final isPutOption =
        upperSymbol.endsWith('PE') || upperSymbol.contains('PE');

    final isOption = isCallOption || isPutOption;

    // ------------------------------------------------------------
    // Market instrument
    //
    // NIFTY + Futures retain the existing convergence behavior.
    // Options get their own 130-150 convergence behavior.
    // ------------------------------------------------------------

    final isMarketInstrument = isSpot || isFuture;

    // ------------------------------------------------------------
    // Price range
    // ------------------------------------------------------------

    final double minPrice;
    final double maxPrice;

    if (isMarketInstrument) {
      minPrice = 22000.0;
      maxPrice = 22500.0;
    } else if (isOption) {
      // Options are allowed to move into the 130-150 range.
      minPrice = 1.0;
      maxPrice = 1000.0;
    } else {
      minPrice = 1.0;
      maxPrice = 1000.0;
    }

    // ------------------------------------------------------------
    // Initial price
    // ------------------------------------------------------------

    var price = _livePrices[symbolId] ?? initialPriceForSymbol(symbolId);

    // ------------------------------------------------------------
    // FUTURES
    //
    // If no previous historical futures price exists,
    // start close to NIFTY with a small basis.
    // ------------------------------------------------------------

    if (isFuture && !_livePrices.containsKey(symbolId)) {
      final spotPrice = _livePrices['NIFTY'] ?? _niftyLivePrice;

      final basis = 5.0 + _random.nextDouble() * 15.0;

      price = spotPrice + basis;
    }

    // ------------------------------------------------------------
    // OPTIONS
    //
    // If there is no existing price, start from a reasonable
    // option premium rather than immediately starting at 130-150.
    //
    // The final candles will gradually converge toward 130-150.
    // ------------------------------------------------------------

    if (isOption && !_livePrices.containsKey(symbolId)) {
      price = 80.0 + _random.nextDouble() * 35.0;
    }

    price = price.clamp(minPrice, maxPrice).toDouble();

    price = roundTo(price, precision);

    // ------------------------------------------------------------
    // Movement
    // ------------------------------------------------------------

    final maxMovement = isMarketInstrument
        ? 25.0
        : isOption
        ? 8.0
        : 5.0;

    // ------------------------------------------------------------
    // NIFTY / FUTURES CONVERGENCE
    // ------------------------------------------------------------

    const marketConvergenceBars = 20;

    const marketTargetMin = 22100.0;
    const marketTargetMax = 22200.0;

    // ------------------------------------------------------------
    // OPTIONS CONVERGENCE
    //
    // Last 20 candles:
    //     gradually move toward 130-150
    //
    // Last 10 candles:
    //     stronger upward/steeper movement
    //
    // Final candles:
    //     stay tightly around 130-150.
    // ------------------------------------------------------------

    const optionConvergenceBars = 20;

    const optionTargetMin = 110.0;
    const optionTargetMax = 120.0;

    final bars = <List<dynamic>>[];

    // ------------------------------------------------------------
    // Generate OHLCV
    // ------------------------------------------------------------

    for (var i = 0; i < barCount; i++) {
      final timestamp = startTime + (i * intervalMs);

      final barsRemaining = barCount - 1 - i;

      // ============================================================
      // MARKET CONVERGENCE
      //
      // NIFTY / FUTURES only
      // ============================================================

      double marketConvergence = 0.0;

      if (isMarketInstrument && barsRemaining < marketConvergenceBars) {
        final barsIntoConvergence = marketConvergenceBars - barsRemaining;

        marketConvergence = (barsIntoConvergence / marketConvergenceBars).clamp(
          0.0,
          1.0,
        );
      }

      // ============================================================
      // OPTION CONVERGENCE
      // ============================================================

      double optionConvergence = 0.0;

      if (isOption && barsRemaining < optionConvergenceBars) {
        final barsIntoConvergence = optionConvergenceBars - barsRemaining;

        optionConvergence = (barsIntoConvergence / optionConvergenceBars).clamp(
          0.0,
          1.0,
        );
      }

      // ------------------------------------------------------------
      // Open
      // ------------------------------------------------------------

      final open = price;

      // ------------------------------------------------------------
      // Normal random movement
      // ------------------------------------------------------------

      final movement = (_random.nextDouble() - 0.5) * (maxMovement * 2);

      double closePrice = open + movement;

      // ============================================================
      // NIFTY / FUTURES
      //
      // Existing 22100-22200 convergence.
      // ============================================================

      if (isMarketInstrument && marketConvergence > 0.0) {
        final targetPrice =
            marketTargetMin +
            _random.nextDouble() * (marketTargetMax - marketTargetMin);

        final pullStrength = marketConvergence * 0.65;

        closePrice = closePrice + ((targetPrice - closePrice) * pullStrength);

        final targetNoise =
            (_random.nextDouble() - 0.5) * 20.0 * (1.0 - marketConvergence);

        closePrice += targetNoise;

        // ----------------------------------------------------------
        // Final 10 candles
        // ----------------------------------------------------------

        if (barsRemaining <= 10) {
          final finalPhase = ((10 - barsRemaining) / 10.0).clamp(0.0, 1.0);

          final allowedOutsideRange = 10.0 * (1.0 - finalPhase);

          closePrice = closePrice.clamp(
            marketTargetMin - allowedOutsideRange,
            marketTargetMax + allowedOutsideRange,
          );

          if (finalPhase > 0.5) {
            final finalTarget =
                marketTargetMin +
                _random.nextDouble() * (marketTargetMax - marketTargetMin);

            closePrice =
                closePrice + ((finalTarget - closePrice) * finalPhase * 0.6);
          }
        }
      }

      // ============================================================
      // OPTIONS
      //
      // Gradually rise/steepen toward 130-150.
      // ============================================================

      if (isOption && optionConvergence > 0.0) {
        // ----------------------------------------------------------
        // Random target between 130 and 150.
        // ----------------------------------------------------------

        final targetPrice =
            optionTargetMin +
            _random.nextDouble() * (optionTargetMax - optionTargetMin);

        // ----------------------------------------------------------
        // First 20 candles
        //
        // Gradual pull.
        //
        // Example:
        // candle 1  -> weak pull
        // candle 10 -> medium pull
        // candle 20 -> strong pull
        // ----------------------------------------------------------

        double pullStrength = optionConvergence * 0.45;

        // ----------------------------------------------------------
        // Last 10 candles
        //
        // Make the rise noticeably steeper.
        // ----------------------------------------------------------

        if (barsRemaining <= 10) {
          final finalPhase = ((10 - barsRemaining) / 10.0).clamp(0.0, 1.0);

          // Starts around 0.45 and increases toward 0.90.
          pullStrength = 0.45 + (finalPhase * 0.45);
        }

        // Pull current close toward target.
        closePrice = closePrice + ((targetPrice - closePrice) * pullStrength);

        // ----------------------------------------------------------
        // Positive bias in final 10 candles.
        //
        // This makes the chart visually rise rather than simply
        // oscillate around the target.
        // ----------------------------------------------------------

        if (barsRemaining <= 10) {
          final finalPhase = ((10 - barsRemaining) / 10.0).clamp(0.0, 1.0);

          final upwardBias = 1.5 + (finalPhase * 3.0);

          closePrice += upwardBias;

          // Small noise so it doesn't look completely artificial.
          final noise = (_random.nextDouble() - 0.5) * 2.0 * (1.0 - finalPhase);

          closePrice += noise;
        }

        // ----------------------------------------------------------
        // Final 5 candles
        //
        // Tighten price into 130-150.
        // ----------------------------------------------------------

        if (barsRemaining <= 5) {
          final finalPhase = ((5 - barsRemaining) / 5.0).clamp(0.0, 1.0);

          final finalTarget =
              optionTargetMin +
              _random.nextDouble() * (optionTargetMax - optionTargetMin);

          closePrice =
              closePrice +
              ((finalTarget - closePrice) * (0.65 + finalPhase * 0.25));

          // Prevent excessive movement outside target.
          final allowedOutside = 5.0 * (1.0 - finalPhase);

          closePrice = closePrice.clamp(
            optionTargetMin - allowedOutside,
            optionTargetMax + allowedOutside,
          );
        }
      }

      // ------------------------------------------------------------
      // Close
      // ------------------------------------------------------------

      final close = roundTo(
        closePrice.clamp(minPrice, maxPrice).toDouble(),
        precision,
      );

      // ------------------------------------------------------------
      // Wicks
      // ------------------------------------------------------------

      final upperWick = _random.nextDouble() * (maxMovement * 0.5);

      final lowerWick = _random.nextDouble() * (maxMovement * 0.5);

      double highPrice = max(open, close) + upperWick;

      double lowPrice = min(open, close) - lowerWick;

      // ============================================================
      // NIFTY / FUTURES WICK CONTROL
      // ============================================================

      if (isMarketInstrument && barsRemaining <= 10) {
        highPrice = min(highPrice, marketTargetMax + 15.0);

        lowPrice = max(lowPrice, marketTargetMin - 15.0);
      }

      // ============================================================
      // OPTION WICK CONTROL
      //
      // Keep the final candles visually around 130-150.
      // ============================================================

      if (isOption && barsRemaining <= 10) {
        highPrice = min(highPrice, optionTargetMax + 8.0);

        lowPrice = max(lowPrice, optionTargetMin - 8.0);
      }

      // ------------------------------------------------------------
      // High / Low
      // ------------------------------------------------------------

      final high = roundTo(
        highPrice.clamp(minPrice, maxPrice).toDouble(),
        precision,
      );

      final low = roundTo(
        lowPrice.clamp(minPrice, maxPrice).toDouble(),
        precision,
      );

      // ------------------------------------------------------------
      // Volume
      // ------------------------------------------------------------

      final volume = 1000 + _random.nextInt(10000);

      // ------------------------------------------------------------
      // Candle
      //
      // [timestamp, open, high, low, close, volume]
      // ------------------------------------------------------------

      bars.add([timestamp, roundTo(open, precision), high, low, close, volume]);

      // ------------------------------------------------------------
      // Next candle starts from previous close.
      // ------------------------------------------------------------

      price = close;
    }

    // ------------------------------------------------------------
    // Save last historical close for streaming.
    // ------------------------------------------------------------

    if (bars.isNotEmpty) {
      final lastClose = toDouble(bars.last[4]);

      _livePrices[symbolId] = lastClose;

      if (isSpot) {
        _niftyLivePrice = lastClose;
      }
    }

    ticks.clear();

    return bars;
  }

  // ---------------------------------------------------------------------------
  // Live ticks
  // ---------------------------------------------------------------------------

  double _random3() =>
      double.parse(((_random.nextDouble() - 0.48) * 10).toStringAsFixed(3));

  List<Map<String, dynamic>> generateTicks() {
    ticks.clear();

    final now = DateTime.now().millisecondsSinceEpoch;

    // ============================================================
    // CONSTANT PRICE RANGES
    // ============================================================

    const double niftyMin = 22100.0;
    const double niftyMax = 22150.0;

    const double futureMin = 22100.0;
    const double futureMax = 22150.0;

    const double optionMin = 110.0;
    const double optionMax = 125.0;

    // ============================================================
    // 1. SPOT / NIFTY
    // ============================================================

    var spotPrice = _livePrices['NIFTY'];

    // ------------------------------------------------------------
    // First time: initialize NIFTY inside 22100 - 22150
    // ------------------------------------------------------------

    if (spotPrice == null || spotPrice < niftyMin || spotPrice > niftyMax) {
      spotPrice = niftyMin + (_random.nextDouble() * (niftyMax - niftyMin));
    }

    // ------------------------------------------------------------
    // Spot movement: -2 to +2
    // ------------------------------------------------------------

    final spotMovement = (_random.nextDouble() - 0.5) * 4.0;

    spotPrice += spotMovement;

    // ------------------------------------------------------------
    // Keep NIFTY strictly between 22100 - 22150
    // ------------------------------------------------------------

    spotPrice = spotPrice.clamp(niftyMin, niftyMax).toDouble();

    spotPrice = roundTo(spotPrice, precision);

    // ------------------------------------------------------------
    // Save Spot live price
    // ------------------------------------------------------------

    _niftyLivePrice = spotPrice;
    _livePrices['NIFTY'] = spotPrice;

    // ------------------------------------------------------------
    // Spot change
    // ------------------------------------------------------------

    final previousSpot = _previousTickPrices['NIFTY'] ?? spotPrice;

    final spotChange = roundTo(spotPrice - previousSpot, precision);

    final spotChangePer = previousSpot != 0
        ? roundTo((spotChange / previousSpot) * 100, 2)
        : 0.0;

    _previousTickPrices['NIFTY'] = spotPrice;

    // ------------------------------------------------------------
    // Add Spot tick
    // ------------------------------------------------------------

    ticks.add({
      'symbolId': 'NIFTY',

      'ltp': spotPrice,
      'dayClose': spotPrice,

      'ltq': 10 + _random.nextInt(90),

      'chng': spotChange,
      'chngPer': spotChangePer,

      'ltt': now,

      'oiChngPer': (_random.nextDouble() - 0.5) * 2,

      'oi': _random3(),
      'volume': _random3(),

      'delta': _random3(),
      'gamma': _random3(),
      'theta': _random3(),
      'vega': _random3(),
    });

    // ============================================================
    // 2. OPTIONS
    // ============================================================

    for (final option in optionChain) {
      final symbolId =
          option['symbolId']?.toString() ??
          option['symbol']?.toString() ??
          option['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        continue;
      }

      // ----------------------------------------------------------
      // Get current option price
      // ----------------------------------------------------------

      var optionPrice = _livePrices[symbolId];

      // ----------------------------------------------------------
      // First time / invalid price
      // Initialize between 110 - 125
      // ----------------------------------------------------------

      if (optionPrice == null ||
          optionPrice < optionMin ||
          optionPrice > optionMax) {
        optionPrice =
            optionMin + (_random.nextDouble() * (optionMax - optionMin));
      }

      // ----------------------------------------------------------
      // Option movement: -1 to +1
      // ----------------------------------------------------------

      final optionMovement = (_random.nextDouble() - 0.5) * 2.0;

      optionPrice += optionMovement;

      // ----------------------------------------------------------
      // Keep option price between 110 - 125
      // ----------------------------------------------------------

      optionPrice = optionPrice.clamp(optionMin, optionMax).toDouble();

      optionPrice = roundTo(optionPrice, precision);

      // ----------------------------------------------------------
      // Save option live price
      // ----------------------------------------------------------

      _livePrices[symbolId] = optionPrice;

      // ----------------------------------------------------------
      // Option change
      // ----------------------------------------------------------

      final previousOption = _previousTickPrices[symbolId] ?? optionPrice;

      final optionChange = roundTo(optionPrice - previousOption, precision);

      final optionChangePer = previousOption != 0
          ? roundTo((optionChange / previousOption) * 100, 2)
          : 0.0;

      _previousTickPrices[symbolId] = optionPrice;

      // ----------------------------------------------------------
      // Add Option tick
      // ----------------------------------------------------------

      ticks.add({
        ...option,

        'symbolId': symbolId,

        'ltp': optionPrice,
        'dayClose': optionPrice,

        'ltq': 1 + _random.nextInt(99),

        'chng': optionChange,
        'chngPer': optionChangePer,

        'ltt': now,

        'oiChngPer': (_random.nextDouble() - 0.5) * 2,

        'OI': _random3(),

        'vWap': option['vWap'] ?? optionPrice,

        'vol': _random3(),

        'delta': _random3(),
        'gamma': _random3(),
        'theta': _random3(),
        'vega': _random3(),
      });
    }

    // ============================================================
    // 3. FUTURES
    // ============================================================

    for (final future in generateFutureSymbols()) {
      final symbolId =
          future['symbolId']?.toString() ??
          future['symbol']?.toString() ??
          future['id']?.toString();

      if (symbolId == null || symbolId.isEmpty) {
        continue;
      }

      // ----------------------------------------------------------
      // Get current Future price
      // ----------------------------------------------------------

      var futurePrice = _livePrices[symbolId];

      // ----------------------------------------------------------
      // First time / invalid price
      // Initialize between 22100 - 22150
      // ----------------------------------------------------------

      if (futurePrice == null ||
          futurePrice < futureMin ||
          futurePrice > futureMax) {
        futurePrice =
            futureMin + (_random.nextDouble() * (futureMax - futureMin));
      }

      // ----------------------------------------------------------
      // Future movement: -2 to +2
      //
      // Same range/movement style as NIFTY.
      // ----------------------------------------------------------

      final futureMovement = (_random.nextDouble() - 0.5) * 4.0;

      futurePrice += futureMovement;

      // ----------------------------------------------------------
      // Keep Future between 22100 - 22150
      // ----------------------------------------------------------

      futurePrice = futurePrice.clamp(futureMin, futureMax).toDouble();

      futurePrice = roundTo(futurePrice, precision);

      // ----------------------------------------------------------
      // Save Future live price
      // ----------------------------------------------------------

      _livePrices[symbolId] = futurePrice;

      // Also update future map.
      future['ltp'] = futurePrice;

      // ----------------------------------------------------------
      // Previous Future price
      // ----------------------------------------------------------

      final previousFuture = _previousTickPrices[symbolId] ?? futurePrice;

      // ----------------------------------------------------------
      // Future change
      // ----------------------------------------------------------

      final futureChange = roundTo(futurePrice - previousFuture, precision);

      // ----------------------------------------------------------
      // Future change %
      // ----------------------------------------------------------

      final futureChangePer = previousFuture != 0
          ? roundTo((futureChange / previousFuture) * 100, 2)
          : 0.0;

      // ----------------------------------------------------------
      // Save previous Future price
      // ----------------------------------------------------------

      _previousTickPrices[symbolId] = futurePrice;

      // ----------------------------------------------------------
      // Add Future tick
      // ----------------------------------------------------------

      ticks.add({
        ...future,

        'symbolId': symbolId,

        'ltp': futurePrice,
        'dayClose': futurePrice,

        'ltq': 10 + _random.nextInt(90),

        'chng': futureChange,
        'chngPer': futureChangePer,

        'ltt': now,

        'oiChngPer': (_random.nextDouble() - 0.5) * 2,

        'oi': _random3(),

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
    if (optionChain.isEmpty || lastPrice <= 0) {
      return [];
    }

    final atmStrike = nearestStrike(lastPrice);
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
    final strike = toInt(option['strike']) ?? nearestStrike(lastPrice);

    final distance = (strike - nearestStrike(lastPrice)).abs();

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
    final distance = (strike - nearestStrike(lastPrice)).abs();

    final base = max(10000, 100000 - distance * 50);

    final typeMultiplier = type == 'CE' ? 1.0 : 1.2;

    return (base * typeMultiplier).round() + _random.nextInt(25000);
  }

  int generateOiChange() {
    return _random.nextInt(50);
  }

  Map<String, dynamic> oiAnalysisAroundAtm() {
    final atm = nearestStrike(lastPrice);

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
    var price = lastPrice;
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
        'atmStraddlePrice': roundTo(straddle, precision),
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
