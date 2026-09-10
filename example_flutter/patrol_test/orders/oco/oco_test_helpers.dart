import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/data/repositories/nxt_chart_repository.dart';
import 'package:nxtchart/src/presentation/widgets/custom_checkbox.dart';
import 'package:nxtchart/src/presentation/widgets/custom_stepper_field.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../../helpers.dart';

// Shared setup/finder helpers for the OCO Patrol suite (create via SL/TP
// drag, modify, cancel).
//
// New OCO placement has no button anywhere in the app -- it only happens
// by dragging an existing position's SL or TP price-line handle on the
// chart canvas. That in turn requires a real open position, seeded here
// via NxtChartRepository.seedPosition -- positions and OCO orders are
// both backed by real in-memory state on the repository.
//
// The position tag and its SL/TP drag handles all carry real ChartTestKeys
// -- located by key here. Neither the OCO order pad nor the orders-list
// OCO action icons carry a test key of their own, so those are still
// located by text/structure.

const ocoPositionId = 'NIFTY_normal';

// Pumps the app against a fresh NxtChartRepository, opens the chart, then
// seeds one open long position. Live data is off by default so the
// chart's tick never updates -- the SL/TP-vs-LTP validity check only
// applies once a live tick exists, so leaving live data (and therefore the
// tick) off makes every drag deterministic regardless of direction/
// distance, independent of this suite's specific LTP-boundary tests.
//
// seedPosition's own avgPrice defaults to the repository's current last
// price when none is given, so the position's marker (and therefore its
// SL/TP drag handles) is always built somewhere within the visible y-axis
// range.
Future<NxtChartRepository> openChartWithMockPosition(
  PatrolIntegrationTester $, {
  bool liveDataEnabled = false,
  int netQty = 75,
  double? avgPrice,
}) async {
  final mock = NxtChartRepository(
    storageKey: 'scalper_chart',
    liveDataEnabled: liveDataEnabled,
  );
  await openChartAndAwaitLoad($, interfaceOverride: mock);
  mock.seedPosition(netQty: netQty, avgPrice: avgPrice);
  return mock;
}

// Expands the position's price tag (tapping it reveals the SL/TP drag
// handles) then drags the SL or TP handle vertically by [dy] logical
// pixels. Ends the gesture, which is exactly what opens the OCO order pad.
//
// Negative [dy] drags up the screen (higher price); positive drags down
// (lower price) -- standard Flutter screen-coordinate convention.
Future<void> dragPositionHandle(
  PatrolIntegrationTester $, {
  required bool isSL,
  required double dy,
}) async {
  final tagFinder = find.byKey(Key(ChartTestKeys.positionTag(ocoPositionId)));
  await waitUntilPresent($, tagFinder);

  // The tag's own label toggles expanded/collapsed and carries no test
  // key of its own -- it's the first GestureDetector inside the tag while
  // collapsed (the exit button, which sits before it in the row, only
  // renders once expanded).
  await $.tester.tap(
    find
        .descendant(of: tagFinder, matching: find.byType(GestureDetector))
        .first,
  );
  await $.pumpAndSettle();

  final handleKey = isSL
      ? ChartTestKeys.positionSlBtn(ocoPositionId)
      : ChartTestKeys.positionTpBtn(ocoPositionId);
  final handleFinder = find.byKey(Key(handleKey));
  await waitUntilPresent($, handleFinder);
  await $.tester.drag(handleFinder, Offset(0, dy));
  await $.pumpAndSettle();
}

// Full create-via-drag flow: drags the requested leg, checks the *other*
// leg's checkbox, then taps Apply on the OCO order pad that opens.
//
// Dragging a single leg and applying with only it selected places a
// standalone SL/TP order -- a real, both-legs-linked OCO group (the "OCO"
// chip in the orders list) requires both checkboxes selected. Ending the
// drag already seeds the non-dragged leg's price fields with a valid
// default (the existing order's price, or the position's avgPrice with
// none), so checking its box needs no field edits.
//
// Caller must have already opened the chart with a position via
// [openChartWithMockPosition]. The Cancel path and the standalone
// single-leg-selected path are covered by dedicated tests instead of this
// helper.
Future<void> createOcoOrderViaDrag(
  PatrolIntegrationTester $, {
  required bool isSL,
  double dy = 200,
}) async {
  await dragPositionHandle($, isSL: isSL, dy: isSL ? dy : -dy);

  final otherLegLabel = isSL ? 'Set Target Price' : 'Set Stop Loss';
  await $.tester.tap(
    find
        .descendant(
          of: _ocoLegBlock(otherLegLabel),
          matching: find.byType(CustomCheckbox),
        )
        .first,
  );
  await $.pumpAndSettle();

  await $.tester.tap(find.text('Apply'));
  await $.pumpAndSettle();
}

// The nearest Column ancestor of an OCO leg's "Set Stop Loss"/
// "Set Target Price" label -- each leg's type label + price inputs are
// wrapped in exactly one Column. Used to scope a lookup to the specific
// leg's own fields, since neither leg carries any test key.
Finder _ocoLegBlock(String legLabel) =>
    find.ancestor(of: find.text(legLabel), matching: find.byType(Column)).first;

// The CustomStepperField widgets inside an OCO leg's block, in build
// order: [0] is always the price field, [1] (if present) is the trigger
// field -- absent only for a standalone TP, which shows "Same as limit
// price" text instead.
List<CustomStepperField> ocoLegFields(String legLabel) {
  return find
      .descendant(
        of: _ocoLegBlock(legLabel),
        matching: find.byType(CustomStepperField),
      )
      .evaluate()
      .map((e) => e.widget as CustomStepperField)
      .toList();
}

// The OCO order row's own Column, scoped via its "OCO" type chip -- unique
// to OCO rows, since plain orders show their own order-type shortLabel
// ('MKT'/'LMT'/...) instead.
Finder _ocoRowBlock() =>
    find.ancestor(of: find.text('OCO'), matching: find.byType(Column)).first;

// Taps the OCO row's Modify (index 0) or Cancel (index 1) action icon --
// neither carries a test key, and both sit inside a Row alongside an
// expand-indicator icon. Located by position among that row's
// GestureDetectors rather than by key, and tapped via raw RenderBox
// centre (bypassing patrol's own hit-testable-visibility check, same
// class of workaround used throughout this suite).
Future<void> _tapOcoAction(
  PatrolIntegrationTester $, {
  required int index,
}) async {
  final elements = find
      .descendant(of: _ocoRowBlock(), matching: find.byType(GestureDetector))
      .evaluate()
      .toList();
  final box = elements[index].renderObject! as RenderBox;
  final centre = box.localToGlobal(
    Offset(box.size.width / 2, box.size.height / 2),
  );
  await $.tester.tapAt(centre);
  await $.pumpAndSettle();
}

Future<void> tapOcoModifyIcon(PatrolIntegrationTester $) =>
    _tapOcoAction($, index: 0);

Future<void> tapOcoCancelIcon(PatrolIntegrationTester $) =>
    _tapOcoAction($, index: 1);
