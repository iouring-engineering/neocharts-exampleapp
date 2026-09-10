import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/data/repositories/nxt_chart_repository.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';

// Shared setup/finder helpers for the Positions Patrol suite (add / adjust /
// exit / list, plus the on-chart marker's own SL/TP drag). Ignores
// group_adjust entirely -- that's a distinct, option-chain-driven
// multi-position flow, covered separately under group_adjust/.
//
// Runs against NxtChartRepository, which already supports positions
// (seedPosition/positionsStreamer). Live data stays on (the default) --
// none of add/adjust/exit's validation has an LTP-boundary check to work
// around by turning ticks off (only OCO's SL/TP-vs-LTP check does, and
// that's covered separately in orders/oco/).
//
// Every field, action, and row in the positions list/add/adjust/exit
// panels carries a real ChartTestKeys entry -- every finder here locates
// by key, not by text/type/structure.

const positionId = 'NIFTY_normal';

// Pumps the app against a fresh NxtChartRepository, opens the chart, then
// seeds one open long position. seedPosition's own avgPrice defaults to
// the repository's current last price when none is given, so the
// position's on-chart marker (relevant to the drag test in this folder) is
// always built somewhere within the visible y-axis range.
Future<NxtChartRepository> openChartWithMockPosition(
  PatrolIntegrationTester $, {
  int netQty = 75,
  double? avgPrice,
}) async {
  final mock = NxtChartRepository(storageKey: 'scalper_chart');
  await openChartAndAwaitLoad($, interfaceOverride: mock);
  mock.seedPosition(netQty: netQty, avgPrice: avgPrice);
  return mock;
}

// The single seeded position's own list row.
Finder findPositionListItem() =>
    find.byKey(Key(ChartTestKeys.positionListItem(positionId)));

Future<void> tapPositionAddIcon(PatrolIntegrationTester $) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.positionListAddBtn(positionId))),
  );
  await $.pumpAndSettle();
}

Future<void> tapPositionAdjustIcon(PatrolIntegrationTester $) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.positionListAdjustBtn(positionId))),
  );
  await $.pumpAndSettle();
}

Future<void> tapPositionExitIcon(PatrolIntegrationTester $) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.positionListExitBtn(positionId))),
  );
  await $.pumpAndSettle();
}

// Expands the position's price tag (tapping it reveals the SL/TP drag
// handles) then drags the SL or TP handle vertically by [dy] logical
// pixels. Ends the gesture, which is exactly what opens the OCO order pad.
// This only proves the drag entry point is reachable from the positions
// feature's own on-chart marker -- the full OCO create/modify/cancel
// lifecycle is already exhaustively covered in orders/oco/.
Future<void> dragPositionHandle(
  PatrolIntegrationTester $, {
  required bool isSL,
  double dy = 200,
}) async {
  // The position tag and its SL/TP drag handles all carry real,
  // precisely-sized ChartTestKeys, unlike the marker's own map key (which
  // the chart canvas wraps in a KeyedSubtree sitting directly above a
  // ClipRect sized to the whole panel graph area, not the small tag).
  final tagFinder = find.byKey(Key(ChartTestKeys.positionTag(positionId)));
  await waitUntilPresent($, tagFinder);
  // Tapping the tag expands it to reveal the SL/TP handles. The tag's own
  // label toggle carries no test key of its own -- it's the first
  // GestureDetector inside the tag while collapsed (the exit button, which
  // sits before it, only renders once expanded).
  final entryTapFinder = find
      .descendant(of: tagFinder, matching: find.byType(GestureDetector))
      .first;
  await $.tester.tap(entryTapFinder);
  await $.pumpAndSettle();

  final handleFinder = find.byKey(
    Key(
      isSL
          ? ChartTestKeys.positionSlBtn(positionId)
          : ChartTestKeys.positionTpBtn(positionId),
    ),
  );
  await waitUntilPresent($, handleFinder);
  await $.tester.drag(handleFinder, Offset(0, isSL ? dy : -dy));
  await $.pumpAndSettle();
}
