import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:nxtchart/interface.dart';

/// The quote dashboard's day numbers.
typedef DayQuote = ({
  double ltp,
  double open,
  double high,
  double low,
  double prevClose,
});

/// The example's [UniChartHost] with every line group: chart data and line
/// streams come from the same mock [NeoChartsRepository] the full chart uses,
/// and every action is reported through [onAction]. A real host opens its own
/// order pad, modify screen or alert editor in each callback instead.
class UniChartRepository
    implements
        UniChartHost,
        UniOrderLines,
        UniOcoLines,
        UniPositionLines,
        UniAlertLines {
  UniChartRepository({required this.base, required this.onAction}) {
    // Before the chart's own load: the mock moves its live price to the
    // last bar of each load, so this one must not land after the chart's.
    final now = DateTime.now().millisecondsSinceEpoch;
    base
        .loadData(
          CandleRequest(
            symbolId: symbol.id,
            from: now - 5 * Duration.millisecondsPerDay,
            to: now,
            intervalSeconds: Duration.secondsPerDay,
            requiredBars: 5,
          ),
        )
        .then(_setPrevClose);
  }

  final NeoChartsRepository base;

  /// Receives a one-line description of each chart action.
  final void Function(String action) onAction;

  /// Seeded from the chart's own newest load, then moved by its ticks; null
  /// until the first load.
  final quote = ValueNotifier<DayQuote?>(null);

  int _quoteBarTime = 0;
  double? _prevClose;
  bool _disposed = false;

  @override
  SymbolInfo get symbol => base.initialSymbol;

  @override
  Map<String, MarketTiming> get marketTimings => base.marketTimings;

  @override
  String get storageKey => base.storageKey;

  @override
  Future<List<OHLC>> loadData(CandleRequest request) async {
    final bars = await base.loadData(request);
    _seedQuote(bars, request.intervalSeconds);

    return bars;
  }

  @override
  Stream<List<ChartTick>> marketData(Set<String> symbolIds) =>
      base.marketData(symbolIds).map((ticks) {
        for (final tick in ticks) {
          if (tick.symbol == symbol.id) _applyTick(tick);
        }

        return ticks;
      });

  @override
  void dispose() {
    _disposed = true;
    quote.dispose();
    base.dispose();
  }

  // The newest bar's date is the day; older history pages and weekly or
  // longer bars are skipped.
  void _seedQuote(List<OHLC> bars, int intervalSeconds) {
    if (bars.isEmpty || intervalSeconds > Duration.secondsPerDay) return;
    final last = bars.last;
    if (last.time < _quoteBarTime) return;
    _quoteBarTime = last.time;

    final lastDate = DateTime.fromMillisecondsSinceEpoch(last.time);
    final dayStart = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    ).millisecondsSinceEpoch;
    final firstToday = bars.indexWhere((bar) => bar.time >= dayStart);
    final today = bars.sublist(firstToday);

    quote.value = (
      ltp: last.close,
      open: today.first.open,
      high: today.map((bar) => bar.high).reduce(max),
      low: today.map((bar) => bar.low).reduce(min),
      prevClose:
          _prevClose ??
          (firstToday > 0 ? bars[firstToday - 1].close : today.first.open),
    );
  }

  // The second-to-last daily bar is yesterday.
  void _setPrevClose(List<OHLC> days) {
    if (_disposed || days.length < 2) return;
    final prevClose = _prevClose = days[days.length - 2].close;
    final current = quote.value;
    if (current == null) return;

    quote.value = (
      ltp: current.ltp,
      open: current.open,
      high: current.high,
      low: current.low,
      prevClose: prevClose,
    );
  }

  void _applyTick(ChartTick tick) {
    final ltp = double.tryParse(tick.ltp);
    final current = quote.value;
    if (ltp == null || current == null) return;

    quote.value = (
      ltp: ltp,
      open: current.open,
      high: max(current.high, ltp),
      low: min(current.low, ltp),
      prevClose: current.prevClose,
    );
  }

  @override
  Stream<List<Order>> get orders => base.orders;

  @override
  Stream<List<OCOOrder>> get ocoOrders => base.ocoOrders;

  @override
  Stream<List<Position>> get positions => base.positions;

  @override
  Stream<List<Alert>> get alerts => base.alerts;

  /// The `onTrade` handler for `NeoChartPage.uni`.
  void onTrade(TradeIntent intent) => onAction(
    [
      'onTrade:',
      ?intent.side?.value,
      ?intent.orderType?.value,
      if (intent.price != null) '@ ${intent.price}',
      if (intent.qty != null) 'qty ${intent.qty}',
      ?intent.productType,
    ].join(' '),
  );

  @override
  void onModifyOrder(String orderId, double price) =>
      onAction('onModifyOrder: $orderId to $price');

  @override
  void onCancelOrder(String orderId) => onAction('onCancelOrder: $orderId');

  @override
  void onModifyOcoLeg(
    String groupId, {
    required OcoLeg leg,
    required double price,
  }) => onAction(
    'onModifyOcoLeg: $groupId '
    '${leg == OcoLeg.stopLoss ? 'stop-loss' : 'target'} to $price',
  );

  @override
  void onCancelOco(String groupId) => onAction('onCancelOco: $groupId');

  @override
  void onCreateAlert(double price) => onAction('onCreateAlert: @ $price');

  @override
  void onModifyAlert(String alertId, double price) =>
      onAction('onModifyAlert: $alertId to $price');

  @override
  void onDeleteAlert(String alertId) => onAction('onDeleteAlert: $alertId');
}
