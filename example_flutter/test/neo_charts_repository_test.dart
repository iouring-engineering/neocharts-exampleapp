import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:nxtchart/interface.dart';

/// [stream]'s first event after [act] runs; [replayed] streams (the state
/// ones) first replay their snapshot, which is skipped.
Future<T> nextAfter<T>(
  Stream<T> stream,
  void Function() act, {
  bool replayed = true,
}) {
  final next = stream.skip(replayed ? 1 : 0).first;
  act();

  return next;
}

OrderParams leg(String symbolId, String action, String productType) =>
    OrderParams(
      symID: symbolId,
      price: 100,
      orderType: 'limit',
      orderAction: action,
      qty: 65,
      productType: productType,
    );

OCOPlaceOrderRequestParams ocoParams(
  OrderAction side,
  double stop,
  double target, {
  String? groupId,
  int qty = 65,
}) => OCOPlaceOrderRequestParams(
  side: side,
  productType: 'intraday',
  stopPrice: stop,
  stopTriggerPrice: stop,
  stopQty: qty,
  symID: 'NIFTY',
  targetPrice: target,
  targetQty: qty,
  targetTriggerPrice: target,
  groupId: groupId,
);

void main() {
  test('optionChain is per underlying', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    final chain = await repo.optionChain('RELIANCE');
    expect(chain, isNotEmpty);
    expect(chain.every((s) => s.undID == 'RELIANCE'), isTrue);
    expect(chain.every((s) => s.segment == Segment.option), isTrue);
    expect((await repo.futures('RELIANCE')).single.undID, 'RELIANCE');
    final top = await repo.fetchTopOptions('RELIANCE');
    expect(top, isNotEmpty);
    expect(top.every((s) => s.undID == 'RELIANCE'), isTrue);
    final oi = await repo.oi(underlyingSymbolId: 'RELIANCE', expiries: []);
    expect(oi.calls.keys.toSet(), {
      for (final s in chain) double.parse(s.strike),
    });
    repo.dispose();
  });
  test('underlyingOf is total', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    final opt = (await repo.optionChain('BANKNIFTY')).first;
    expect((await repo.underlyingOf(opt.id)).id, 'BANKNIFTY');
    expect((await repo.underlyingOf('TCS')).id, 'TCS');
    repo
      ..dispose()
      ..dispose(); // idempotent
  });
  test('marketData replaces the subscribed set', () async {
    final repo = NeoChartsRepository();
    repo.marketData({'NIFTY', 'BANKNIFTY'});
    final ticks = await repo.marketData({'RELIANCE'}).first;
    expect(ticks.map((t) => t.symbol).toSet(), {'RELIANCE'});
    repo.dispose();
  });
  test('every tradable symbol and seed has a product type', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    for (final s in await repo.searchSymbols('')) {
      if (s.lotSize > 0) {
        expect(repo.productTypes[s.segment], isNotNull, reason: s.id);
      }
    }
    for (final types in repo.productTypes.values) {
      expect(types.defaultValue.trim(), isNotEmpty);
    }
    void declared(SymbolInfo symbol, String productType) => expect(
      repo.productTypes[symbol.segment]!.values,
      contains(productType),
      reason: symbol.id,
    );
    final positions = await nextAfter(repo.positions, repo.seedPosition);
    for (final p in positions) {
      declared(p.symbolInfo, p.productType);
    }
    final seeded = await nextAfter(repo.positions, () => repo.seedPositions(6));
    for (final p in seeded) {
      declared(p.symbolInfo, p.productType);
    }
    for (final o in await nextAfter(repo.orders, () => repo.seedOrders(2))) {
      declared(o.symbolInfo, o.productType);
    }
    repo.dispose();
  });
  test('a Buy order nets its own product type position', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    repo.seedPosition(netQty: 75, productType: 'intraday');
    final positions = await nextAfter(
      repo.positions,
      () => repo.placeOrder(leg('NIFTY', 'Buy', 'intraday')),
    );
    expect(positions.singleWhere((p) => p.symbolId == 'NIFTY').netQty, 140);
    repo.dispose();
  });
  test('cancelOcoOrder removes the group', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    final placed = await nextAfter(
      repo.ocoOrders,
      () => repo.placeOcoOrder(
        const OCOPlaceOrderRequestParams(
          side: OrderAction.sell,
          productType: 'intraday',
          stopPrice: 22000,
          stopTriggerPrice: 22000,
          stopQty: 65,
          symID: 'NIFTY',
          targetPrice: 22300,
          targetQty: 65,
          targetTriggerPrice: 22300,
        ),
      ),
    );
    final groupId = placed.single.groupId;
    final left = await nextAfter(
      repo.ocoOrders,
      () => repo.cancelOcoOrder(groupId),
    );
    expect(left, isEmpty);
    repo.dispose();
  });
  test('group adjust keeps each leg product type', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    final option = (await repo.optionChain('BANKNIFTY')).first;
    final orders = repo.orders.skip(1).first;
    final positions = await nextAfter(
      repo.positions,
      () => repo.groupAdjustOrders(
        GroupAdjustRequest(
          exit: const [],
          add: [leg(option.id, 'Buy', 'intraday')],
        ),
      ),
    );
    final added = positions.singleWhere((p) => p.symbolId == option.id);
    expect(added.productType, 'intraday');
    expect((await orders).single.productType, 'intraday');
    repo.dispose();
  });
  test('previews need a known symbol and positive inputs', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    MarginRequest margin(String id, int lots, double ltp) => MarginRequest(
      action: OrderAction.buy,
      lots: lots,
      ltp: ltp,
      symbolId: id,
    );
    BrokerageRequest brokerage(String id, int qty, double price) =>
        BrokerageRequest(
          action: OrderAction.buy,
          quantity: qty,
          price: price,
          symbolId: id,
        );
    expect(await repo.marginFor(margin('NIFTY', 1, 100)), 6500);
    expect(await repo.marginFor(margin('NOPE', 1, 100)), isNull);
    expect(await repo.marginFor(margin('NIFTY', 0, 100)), isNull);
    expect(await repo.marginFor(margin('NIFTY', 1, 0)), isNull);
    expect(
      await repo.brokerageFor(brokerage('NIFTY', 65, 100)),
      closeTo(1.95, 1e-9),
    );
    expect(await repo.brokerageFor(brokerage('NOPE', 65, 100)), isNull);
    expect(await repo.brokerageFor(brokerage('NIFTY', 0, 100)), isNull);
    expect(await repo.brokerageFor(brokerage('NIFTY', 65, 0)), isNull);
    repo.dispose();
  });
  test('dispose closes every stream', () async {
    final repo = NeoChartsRepository();
    final done = [
      repo.marketData({'NIFTY'}).drain<void>(),
      repo.orders.drain<void>(),
      repo.positions.drain<void>(),
      repo.ocoOrders.drain<void>(),
      repo.alerts.drain<void>(),
      repo.actionFeedback.drain<void>(),
    ];
    repo.dispose();
    await Future.wait(done).timeout(const Duration(seconds: 1));
  });
  test('a late listener gets the seeded snapshot without a tick', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    expect((await repo.positions.first), isNotEmpty);
    expect(await repo.orders.first, isEmpty);
    expect(await repo.ocoOrders.first, isEmpty);
    expect(await repo.alerts.first, isEmpty);
    repo.dispose();
  });
  test('underlyingOf falls back to NIFTY for an unknown id', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    expect((await repo.underlyingOf('GONE')).id, 'NIFTY');
    repo.dispose();
  });
  test('modify on a missing alert or OCO id sends negative feedback', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    final alert = await nextAfter(
      repo.actionFeedback,
      replayed: false,
      () => repo.modifyAlert(
        const AlertParams(
          alertId: 'NOPE',
          symbolId: 'NIFTY',
          ltp: '1',
          triggerPrice: '2',
        ),
      ),
    );
    expect(alert.sentiment, ActionSentiment.negative);
    final oco = await nextAfter(
      repo.actionFeedback,
      replayed: false,
      () =>
          repo.modifyOcoOrder(ocoParams(OrderAction.sell, 1, 2, groupId: 'X')),
    );
    expect(oco.sentiment, ActionSentiment.negative);
    repo.dispose();
  });
  test('modifyOcoOrder updates the leg quantities', () async {
    final repo = NeoChartsRepository(liveDataEnabled: false);
    final placed = await nextAfter(
      repo.ocoOrders,
      () => repo.placeOcoOrder(ocoParams(OrderAction.sell, 22000, 22300)),
    );
    final modified = await nextAfter(
      repo.ocoOrders,
      () => repo.modifyOcoOrder(
        ocoParams(
          OrderAction.sell,
          22000,
          22300,
          groupId: placed.single.groupId,
          qty: 130,
        ),
      ),
    );
    expect(modified.single.stopLoss.qty, 130);
    expect(modified.single.target.qty, 130);
    repo.dispose();
  });
  group('OCO trigger is side-aware', () {
    // NIFTY streams in a narrow band far from both 1 and 99999.
    Future<List<OCOOrder>> afterTicks(
      WidgetTester tester,
      OrderAction side,
      double sl,
      double tp,
    ) async {
      var latest = <OCOOrder>[];
      final repo = NeoChartsRepository();
      repo.ocoOrders.listen((list) => latest = list);
      repo.placeOcoOrder(ocoParams(side, sl, tp));
      await tester.pump(const Duration(seconds: 3));
      repo.dispose();

      return latest;
    }

    testWidgets('a buy OCO (SL above, TP below) is not triggered', (t) async {
      expect(await afterTicks(t, OrderAction.buy, 99999, 1), hasLength(1));
    });
    testWidgets('a buy OCO triggers once the price crosses its SL', (t) async {
      expect(await afterTicks(t, OrderAction.buy, 1, 99999), isEmpty);
    });
    testWidgets('a sell OCO triggers at its SL', (t) async {
      expect(await afterTicks(t, OrderAction.sell, 99999, 1000000), isEmpty);
    });
    testWidgets('a sell OCO (SL below, TP above) is not triggered', (t) async {
      expect(await afterTicks(t, OrderAction.sell, 1, 99999), hasLength(1));
    });
  });
}
