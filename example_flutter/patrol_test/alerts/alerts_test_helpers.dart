import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';

// Shared setup/finder helpers for the Alerts Patrol suite (create / modify /
// delete via the drawer panel, plus the on-chart marker's own drag-to-modify
// and delete).
//
// Alerts are fully wired in NxtChartRepository -- createAlert/modifyAlert/
// deleteAlert all mutate real in-memory state and re-broadcast it on
// alertsStreamer -- so there's no bespoke setup needed here beyond the
// shared openChartAndAwaitLoad entry point.
//
// Live data stays ON (the default): the create/modify dialog's own
// validation is just non-empty + parseable-as-double, with no LTP-boundary
// check to work around by turning ticks off, and the dialog's price field
// is pre-filled from the live LTP tick.
//
// Every finder here locates by key (ChartTestKeys' alert-list/dialog/
// on-chart-marker sections), not by text/type/structure.

// NxtChartRepository.createAlert assigns ids as 'ALERT001', 'ALERT002', ...
// off a per-instance counter starting at 0; every test in this suite opens
// a fresh chart and creates exactly one alert, so it's always 'ALERT001'.
const alertId = 'ALERT001';

// Opens the alerts panel and taps the "Create Alert" FAB, opening the
// create/modify dialog with its price field pre-filled from the live LTP
// tick.
Future<void> openCreateAlertDialog(PatrolIntegrationTester $) async {
  await openAlertsPanel($);
  await $.tester.tap(find.text('Create Alert'));
  await $.pumpAndSettle();
}

// Sets the create/modify dialog's own trigger-price field. Like the order
// pad's fields, this is a CustomTextField wrapped in an ambient
// NumPadFieldScope, not a bare TextField -- so it's located via the shared
// fieldByKey (which descends to the real TextField) and set via setField
// (which writes the controller directly), not a raw enterText. See
// setField's/clearField's doc comments in helpers.dart for why.
Future<void> setAlertValueField(PatrolIntegrationTester $, String value) =>
    setField($, fieldByKey(ChartTestKeys.alertDialogValueField), value);

Future<void> tapAlertDialogSubmit(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.alertDialogSubmitBtn)));
  await $.pumpAndSettle();
}

// Full create flow: opens the dialog, optionally overwrites the pre-filled
// price, then submits. Every test that just needs *an* alert to exist (for
// modify/delete/chart-marker tests) uses this rather than a seeding method
// -- the dialog's validation has no tick-alignment/LTP-boundary constraint
// to route around, so driving the real UI is no less deterministic than
// seeding would be, and NxtChartRepository exposes no alert-seeding hook
// anyway (only seedPosition(), for the positions suite).
Future<void> createAlert(
  PatrolIntegrationTester $, {
  String? triggerPrice,
}) async {
  await openCreateAlertDialog($);
  if (triggerPrice != null) {
    await setAlertValueField($, triggerPrice);
  }
  await tapAlertDialogSubmit($);
}

// The single created alert's own list row.
Finder findAlertListItem() =>
    find.byKey(Key(ChartTestKeys.alertListItem(alertId)));

Future<void> tapAlertStatusBadge(PatrolIntegrationTester $) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.alertListStatusBadge(alertId))),
  );
  await $.pumpAndSettle();
}

Future<void> tapAlertModifyIcon(PatrolIntegrationTester $) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.alertListModifyBtn(alertId))),
  );
  await $.pumpAndSettle();
}

Future<void> tapAlertDeleteIcon(PatrolIntegrationTester $) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.alertListDeleteBtn(alertId))),
  );
  await $.pumpAndSettle();
}

// The on-chart alert marker -- a draggable, deletable price tag drawn for
// every enabled, untriggered alert -- independent of the alerts-panel list.
// Collapsed to a bell icon; tapping it reveals a drag handle, the symbol's
// name badge, and a delete button.
Finder findAlertChartTag() => find.byKey(Key(ChartTestKeys.alertTag(alertId)));

// Taps the collapsed marker's bell icon to reveal the drag handle + delete
// button. Collapsed, the tag is its own single GestureDetector, so it's
// tapped directly by its key rather than via a descendant lookup.
Future<void> expandAlertChartTag(PatrolIntegrationTester $) async {
  final tagFinder = findAlertChartTag();
  await waitUntilPresent($, tagFinder);
  await $.tester.tap(tagFinder);
  await $.pumpAndSettle();
}

// Expands the tag, then drags its handle by [dy] logical pixels and lets
// the resulting modify dialog settle in. There's no LTP-boundary gate on
// this drag at all (unlike positions' SL/TP), so direction/distance don't
// matter for determinism.
Future<void> dragAlertChartTag(
  PatrolIntegrationTester $, {
  double dy = 150,
}) async {
  await expandAlertChartTag($);
  final dragHandle = find.byKey(Key(ChartTestKeys.alertDragHandle(alertId)));
  await waitUntilPresent($, dragHandle);
  await $.tester.drag(dragHandle, Offset(0, dy));
  await $.pumpAndSettle();
}

// Expands the tag, then taps its on-chart delete button -- fires the same
// delete action as the list's delete icon immediately (no confirmation
// dialog either way).
Future<void> deleteAlertViaChartTag(PatrolIntegrationTester $) async {
  await expandAlertChartTag($);
  final deleteBtn = find.byKey(Key(ChartTestKeys.alertTagDeleteBtn(alertId)));
  await waitUntilPresent($, deleteBtn);
  await $.tester.tap(deleteBtn);
  await $.pumpAndSettle();
}
