import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:nxtchart/interface.dart';

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
  UniChartRepository({required this.base, required this.onAction});

  final NeoChartsRepository base;

  /// Receives a one-line description of each chart action.
  final void Function(String action) onAction;

  @override
  SymbolInfo get symbol => base.initialSymbol;

  @override
  Map<String, MarketTiming> get marketTimings => base.marketTimings;

  @override
  String get storageKey => base.storageKey;

  @override
  Future<List<OHLC>> loadData(CandleRequest request) => base.loadData(request);

  @override
  Stream<List<ChartTick>> marketData(Set<String> symbolIds) =>
      base.marketData(symbolIds);

  @override
  void dispose() => base.dispose();

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
