import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'helpers.dart';

// Order Preferences is only reachable via the indexCallPut layout (the
// dual-panel view's own menu always includes the tab, but the preferences
// it stores only ever get READ back by the right panel's own strike
// resolution -- singleChart's plain chart never resolves a CE/PE contract
// off them).
//
// The right panel's own listener re-resolves its CE/PE strike from a
// saved, non-ATM preference once a live tick exists; the resolved
// preference's lots feed into both its order pad and the crosshair
// quick-buy/sell as the default quantity.
//
// Android Test Orchestrator wipes app data (incl. SharedPreferences)
// between every test, so "already set" preferences can't be seeded in one
// test and read back in the next -- the core scenario below sets, applies,
// then closes+reopens the chart all within a single test to prove the
// round trip through real, persisted storage (the layout selection itself
// is also a persisted preference, so it survives the reopen unprompted).

// Taps the right-hand panel's own canvas to open its order pad -- a
// dual-panel layout occupies the full screen width split between two
// panels, so 75% across always lands inside the right one, mirroring
// helpers.dart's openOrderPad for the single-panel case.
Future<void> _openRightPanelOrderPad(
  PatrolIntegrationTester $, {
  int maxAttempts = 5,
}) async {
  final view = $.tester.view;
  final screenSize = view.physicalSize / view.devicePixelRatio;
  final point = Offset(screenSize.width * 0.75, screenSize.height / 2);
  for (var i = 0; i < maxAttempts; i++) {
    await $.tester.pump(const Duration(milliseconds: 300));
    await $.tester.tapAt(point);
    await $.tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(Key(ChartTestKeys.orderPadBuyBtn)).evaluate().isNotEmpty) {
      return;
    }
  }
  await $.pumpAndSettle();
}

void main() {
  group('Order preferences', () {
    patrolTest(
      'with no saved preference the right panel and order pad default to '
      'ATM and 1 lot',
      ($) async {
        await openChartAndAwaitLoad($);
        await selectChartLayout($, 'indexCallPut');
        await waitUntilPresent(
          $,
          find.byKey(Key(ChartTestKeys.scalperRightStrikeLabel)),
        );

        await _openRightPanelOrderPad($);
        final qty = $.tester
            .widget<TextField>(find.byKey(Key(ChartTestKeys.orderPadQtyField)))
            .controller!
            .text;
        expect(int.parse(qty), 50);
      },
    );

    patrolTest('applying an Index preference shows a confirmation', ($) async {
      await openChartAndAwaitLoad($);
      await selectChartLayout($, 'indexCallPut');
      await openOrderPrefsMenu($);
      await switchOrderPrefsTab($, 'indices');

      await setOrderPrefsStrikeType($, side: 'call', label: 'ITM');
      await incrementOrderPrefsLots($, side: 'call', times: 2);
      await applyOrderPrefs($, 'indices');

      expect(find.text('Changes Applied'), findsOneWidget);

      await closeOrderPrefsMenu($);
    });

    patrolTest(
      'an already-set preference is reflected in the right panel and its '
      'buy or sell lot size once the chart is reopened',
      ($) async {
        await openChartAndAwaitLoad($);
        await selectChartLayout($, 'indexCallPut');
        await waitUntilPresent(
          $,
          find.byKey(Key(ChartTestKeys.scalperRightStrikeLabel)),
        );
        final baseline = $.tester
            .widget<Text>(
              find.byKey(Key(ChartTestKeys.scalperRightStrikeLabel)),
            )
            .data;

        await openOrderPrefsMenu($);
        await switchOrderPrefsTab($, 'indices');
        await setOrderPrefsStrikeType($, side: 'call', label: 'ITM');
        await incrementOrderPrefsOffset($, side: 'call');
        await incrementOrderPrefsLots($, side: 'call', times: 2);
        await setOrderPrefsStrikeType($, side: 'put', label: 'ITM');
        await incrementOrderPrefsLots($, side: 'put', times: 4);
        await applyOrderPrefs($, 'indices');
        expect(find.text('Changes Applied'), findsOneWidget);
        await closeOrderPrefsMenu($);

        // The layout selection is itself a persisted preference, so it's
        // still indexCallPut once the chart reopens -- no need to
        // reselect it.
        await closeAndReopenChart($);
        await waitUntilPresent(
          $,
          find.byKey(Key(ChartTestKeys.scalperRightStrikeLabel)),
        );

        // The preference only re-resolves once a live underlying tick
        // lands -- poll for the label to move off the plain-ATM baseline
        // rather than a fixed settle, since the app streams at 1 tick/s.
        final labelKey = find.byKey(Key(ChartTestKeys.scalperRightStrikeLabel));
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while ($.tester.widget<Text>(labelKey).data == baseline) {
          if (DateTime.now().isAfter(deadline)) {
            throw TestFailure(
              'Right panel never moved off the ATM baseline "$baseline" '
              'after the saved order preference was applied.',
            );
          }
          await $.tester.pump(const Duration(milliseconds: 300));
        }

        await _openRightPanelOrderPad($);
        final qty = $.tester
            .widget<TextField>(find.byKey(Key(ChartTestKeys.orderPadQtyField)))
            .controller!
            .text;
        expect(int.parse(qty), 150);
      },
    );
  });
}
