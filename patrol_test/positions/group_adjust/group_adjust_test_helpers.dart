import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../../helpers.dart';
import '../positions_test_helpers.dart';

// Shared setup/finder helpers for the group-adjust Patrol suite. Reuses
// positions_test_helpers.dart's openChartWithMockPosition/positionId (the
// app only ever seeds one position, 'NIFTY_normal') and helpers.dart's
// openPositionsPanel/openOrderPad-style top-level helpers.
//
// Every field and action button in the group-adjust panel and its option
// chain now carries a real ChartTestKeys entry -- every finder here
// locates by key, not by text/type/structure.
//
// The group-adjust entry point requires at least one selected position and
// a single underlying across all selections -- trivially satisfied here
// since the app only ever seeds one position/underlying ('NIFTY').
//
// Option-chain strike symbol ids are date-derived (expiries are computed
// relative to "now"), so there is no fixed literal to key a *specific*
// strike off. Every finder below that touches the option chain or the
// adjust-to item it produces uses an "any" key-prefix predicate instead
// (mirroring orders_test_helpers.dart's findAnyOrderCancelBtn/
// findAnyOrderChartTag) -- there is at most one adjust-to item in any of
// these tests, so "any" is unambiguous.

Future<void> tapPositionCheckbox(PatrolIntegrationTester $) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.positionListCheckbox(positionId))),
  );
  await $.pumpAndSettle();
}

Future<void> tapGroupAdjustButton(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.groupAdjustBtn)));
  await $.pumpAndSettle();
}

// Selects the seeded position (revealing the Group Adjust button) then
// opens the option chain in group-adjust mode.
Future<void> openGroupAdjustOptionChain(PatrolIntegrationTester $) async {
  await openPositionsPanel($);
  await waitUntilPresent($, findPositionListItem());
  await tapPositionCheckbox($);
  await waitUntilPresent($, find.byKey(Key(ChartTestKeys.groupAdjustBtn)));
  await tapGroupAdjustButton($);
}

Finder findAnyOptionChainStrikeCell() =>
    findByKeyPrefix('chart_option_chain_strike_cell_');

// Taps the first rendered strike cell -- adds it to the adjust list (or
// removes it, if already added; the cell's own tap handler toggles).
Future<void> tapFirstOptionChainStrikeCell(PatrolIntegrationTester $) async {
  final cell = findAnyOptionChainStrikeCell();
  await waitUntilPresent($, cell);
  await $.tester.tap(cell.first);
  await $.pumpAndSettle();
}

Finder findAnyAdjustItemDeleteBtn() =>
    findByKeyPrefix('chart_group_adjust_item_delete_btn_');

Finder findAnyAdjustItemBuyBtn() =>
    findByKeyPrefix('chart_group_adjust_item_buy_btn_');

Finder findAnyAdjustItemSellBtn() =>
    findByKeyPrefix('chart_group_adjust_item_sell_btn_');

// The adjust-to item's own price field wraps its key on the *outer*
// widget -- walks down to the real inner TextField, same rationale as
// helpers.dart's fieldByKey.
Finder findAnyAdjustItemPriceField() => find.descendant(
  of: findByKeyPrefix('chart_group_adjust_item_price_field_'),
  matching: find.byType(TextField),
);

Finder findAnyAdjustItemQtyField() => find.descendant(
  of: findByKeyPrefix('chart_group_adjust_item_qty_field_'),
  matching: find.byType(TextField),
);

// The currently-selected position's own lot-qty field in the group-adjust
// panel's "Current Position" section -- keyed by the fixed seeded position
// id, unlike the adjust-to item fields above.
Finder findCurrentPositionQtyField() => find.descendant(
  of: find.byKey(Key(ChartTestKeys.groupAdjustPositionQtyField(positionId))),
  matching: find.byType(TextField),
);

Future<void> tapGroupAdjustOrderTypeChip(
  PatrolIntegrationTester $,
  String name,
) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.groupAdjustOrderTypeChip(name))),
  );
  await $.pumpAndSettle();
}

Future<void> tapGroupAdjustCancel(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.groupAdjustCancelBtn)));
  await $.pumpAndSettle();
}

Future<void> tapGroupAdjustSubmit(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.groupAdjustSubmitBtn)));
  await $.pumpAndSettle();
}
