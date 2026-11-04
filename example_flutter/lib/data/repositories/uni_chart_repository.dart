import 'package:nxtchart/interface.dart';

/// The example's [UniChartInterface]: chart data and line streams come from
/// the same mock [ChartInterface] the full chart uses, and every action is
/// reported through [onAction]. A real host opens its own order pad, modify
/// screen or alert editor in each `on*` callback instead.
class UniChartRepository implements UniChartInterface {
  UniChartRepository({required this.base, required this.onAction});

  final ChartInterface base;

  /// Receives a one-line description of each chart action.
  final void Function(String action) onAction;

  @override
  String get symbolInfo => base.symbolInfo;

  @override
  String get marketTimings => base.marketTimings;

  @override
  Future<String> loadData({
    required String symbolId,
    required int from,
    required int to,
    required int intervalSeconds,
    required int requiredBars,
  }) => base.loadData(
    symbolId: symbolId,
    from: from,
    to: to,
    intervalSeconds: intervalSeconds,
    requiredBars: requiredBars,
  );

  @override
  Stream<String> marketDataStreamer(String symbols) =>
      base.marketDataStreamer(symbols);

  @override
  String get storageKey => base.storageKey;

  @override
  void dispose() => base.dispose();

  @override
  Stream<String> get ordersStreamer => base.ordersStreamer;

  @override
  Stream<String> get ocoOrdersStreamer => base.ocoOrdersStreamer;

  @override
  Stream<String> get positionsStreamer => base.positionsStreamer;

  @override
  Stream<String> get alertsStreamer => base.alertsStreamer;

  @override
  void onTrade({
    OrderAction? side,
    OrderType? orderType,
    double? price,
    int? qty,
    String? productType,
  }) => onAction(
    [
      'onTrade:',
      ?side?.value,
      ?orderType?.value,
      if (price != null) '@ $price',
      if (qty != null) 'qty $qty',
      ?productType,
    ].join(' '),
  );

  @override
  void onModifyOrder({required String orderId, required double price}) =>
      onAction('onModifyOrder: $orderId to $price');

  @override
  void onCancelOrder({required String orderId}) =>
      onAction('onCancelOrder: $orderId');

  @override
  void onModifyOcoLeg({
    required String groupId,
    required bool isStopLoss,
    required double price,
  }) => onAction(
    'onModifyOcoLeg: $groupId ${isStopLoss ? 'stop-loss' : 'target'} '
    'to $price',
  );

  @override
  void onCancelOco({required String groupId}) =>
      onAction('onCancelOco: $groupId');

  @override
  void onCreateAlert({required double price}) =>
      onAction('onCreateAlert: @ $price');

  @override
  void onModifyAlert({required String alertId, required double price}) =>
      onAction('onModifyAlert: $alertId to $price');

  @override
  void onDeleteAlert({required String alertId}) =>
      onAction('onDeleteAlert: $alertId');
}
