import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/order_type.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';

// Shared setup/finder helpers for the Orders Patrol suite (place / modify /
// cancel). Reuses the top-level helpers (openChartAndAwaitLoad,
// openOrdersPanel, openOrderPad, findAnyOrderCancelBtn/ModifyBtn,
// waitUntilPresent/Absent) rather than duplicating them.
//
// Order placement/modification/cancellation in NxtChartRepository are
// unconditional pass-throughs with no configurable failure, so this suite
// only exercises what's actually observable through it: the client-side
// validation in the order/modify pads, and orders-list/dialog state after
// each action.
//
// Every field, order-type toggle, and action button carries a real
// ChartTestKeys entry -- every finder here locates by key, not by
// text/type/structure.

Future<void> openChartWithMock(PatrolIntegrationTester $) async {
  await openChartAndAwaitLoad($);
}

// Places a market order via the order pad. Explicitly selects "MKT" first
// so the placed order's type is deterministic regardless of whatever order
// type the pad happened to pre-select (seeded from the user's saved order
// preference, not always Market).
Future<void> placeMarketOrder(
  PatrolIntegrationTester $, {
  required bool isBuy,
}) async {
  await openOrderPad($);
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.orderTypeChip(OrderType.market.name))),
  );
  await $.pumpAndSettle();
  await $(
    Key(isBuy ? ChartTestKeys.orderPadBuyBtn : ChartTestKeys.orderPadSellBtn),
  ).tap();
  await $.pumpAndSettle();
}

// Places a limit order via the order pad, at whatever price switching to
// "LMT" auto-fills (seeded from the live ltp tick, tick-aligned by
// construction, so it passes the tick-multiple check as-is).
//
// A market order's price is hardcoded to 0 regardless of what's on screen
// when it's placed, which places its on-chart price line permanently
// outside the visible y-axis range -- so any test that needs to find/drag
// an order's chart marker must place a limit order instead of
// [placeMarketOrder].
Future<void> placeLimitOrder(
  PatrolIntegrationTester $, {
  required bool isBuy,
}) async {
  await openOrderPad($);
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.orderTypeChip(OrderType.limit.name))),
  );
  await $.pumpAndSettle();
  await $(
    Key(isBuy ? ChartTestKeys.orderPadBuyBtn : ChartTestKeys.orderPadSellBtn),
  ).tap();
  await $.pumpAndSettle();
}

// Opens the orders panel, waits for at least one open order to be
// modifiable, and taps the first one's Modify button. Callers must have
// placed an order first (e.g. via [placeMarketOrder]).
Future<void> openModifyPadForFirstOrder(PatrolIntegrationTester $) async {
  await openOrdersPanel($);
  await waitUntilPresent(
    $,
    findAnyOrderModifyBtn(),
    timeout: const Duration(seconds: 20),
  );
  await $.tester.tap(findAnyOrderModifyBtn().first);
  await $.pumpAndSettle();
}

// Opens the orders panel, waits for at least one open order to be
// cancellable, and taps the first one's Cancel button, revealing the
// confirmation dialog. Callers must have placed an order first.
Future<void> openCancelDialogForFirstOrder(PatrolIntegrationTester $) async {
  await openOrdersPanel($);
  await waitUntilPresent(
    $,
    findAnyOrderCancelBtn(),
    timeout: const Duration(seconds: 20),
  );
  await $.tester.tap(findAnyOrderCancelBtn().first);
  await $.pumpAndSettle();
}

// The order pad's own quantity TextField.
Finder orderPadQtyField() => find.byKey(Key(ChartTestKeys.orderPadQtyField));

// The order pad's own price TextField -- shared by both the read-only
// Market display and the editable Limit field, since only one is ever
// built at a time for a given order type. Keyed on the outer field, so
// this walks down to its real inner TextField.
Finder orderPadPriceField() => fieldByKey(ChartTestKeys.orderPadPriceField);

// The modify pad's price TextField.
Finder modifyPadPriceField() => fieldByKey(ChartTestKeys.modifyOrderPriceField);

// The modify pad's trigger-price TextField, only present once the order
// type is switched to Stop Loss.
Finder modifyPadTriggerField() =>
    fieldByKey(ChartTestKeys.modifyOrderTriggerField);

// The modify pad's quantity TextField.
Finder modifyPadQtyField() => fieldByKey(ChartTestKeys.modifyOrderQtyField);

// Taps an order-type chip (MKT/LMT/SL) on either the order pad or the
// modify pad -- both toggle over the same OrderType enum and key their
// chips identically, so one helper covers both entry points.
Future<void> tapOrderTypeChip(PatrolIntegrationTester $, OrderType type) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.orderTypeChip(type.name))));
  await $.pumpAndSettle();
}

Future<void> tapModifySubmit(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.modifyOrderSubmitBtn)));
  await $.pumpAndSettle();
}

// "Any"-order finders below match by real ChartTestKeys prefix rather than
// an exact key -- order IDs are generated by the app, not seeded by the
// test, so there's no fixed ID to key off. Every prefix here is still the
// real ChartTestKeys.xxx(id) string, just matched loosely.

// Finds the first open order's draggable price-line tag on the chart --
// the on-chart counterpart to the orders-list Modify button, reachable
// only by dragging its price line rather than tapping an icon.
Finder findAnyOrderChartTag() => findByKeyPrefix('chart_order_tag_');

// The first open order's own drag handle.
Finder findAnyOrderDragHandle() => findByKeyPrefix('chart_order_drag_');

// The first open order's own on-chart close ("X") button -- only present
// once the tag's label has been tapped (see
// [revealAndTapFirstOrderChartCloseBtn]).
Finder findAnyOrderChartCloseBtn() => findByKeyPrefix('chart_order_close_');

// Drags the first open order's on-chart price line by [dy] logical pixels
// and lets the resulting modify pad settle in. There's no LTP-based
// validity gate here -- the drop always snaps the dropped price to the
// tick size and opens the pad, regardless of direction or distance.
Future<void> dragFirstOrderChartTag(
  PatrolIntegrationTester $, {
  double dy = 150,
}) async {
  final dragHandle = findAnyOrderDragHandle();
  await waitUntilPresent($, dragHandle);
  await $.tester.drag(dragHandle.first, Offset(0, dy));
  await $.pumpAndSettle();
}

// Reveals then taps the first open order's on-chart close ("X") button --
// only shown once the tag's own label has been tapped (the second
// GestureDetector in the tag, right after the drag handle; the label
// itself has no dedicated finder of its own, so it's located by position
// among the tag's own GestureDetectors). This is the on-chart counterpart
// to the orders-list Cancel button, and opens the same cancel dialog.
Future<void> revealAndTapFirstOrderChartCloseBtn(
  PatrolIntegrationTester $,
) async {
  await waitUntilPresent($, findAnyOrderChartTag());
  final label = find
      .descendant(
        of: findAnyOrderChartTag().first,
        matching: find.byType(GestureDetector),
      )
      .at(1);
  await $.tester.tap(label);
  await $.pumpAndSettle();

  final closeBtn = findAnyOrderChartCloseBtn();
  await waitUntilPresent($, closeBtn);
  await $.tester.tap(closeBtn.first);
  await $.pumpAndSettle();
}

Future<void> tapCancelDialogKeep(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.cancelOrderKeepBtn)));
  await $.pumpAndSettle();
}

Future<void> tapCancelDialogConfirm(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.cancelOrderConfirmBtn)));
  await $.pumpAndSettle();
}
