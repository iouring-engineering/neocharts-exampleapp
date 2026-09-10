import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'helpers.dart';

// P&L panel:
//   - Purely a display screen (no interactive controls of its own) that
//     reads totals off the positions bloc's state -- NxtChartRepository
//     seeds a handful of demo positions and streams synthetic ticks for
//     them, so unrealised P&L moves once they're live.
//   - The positions bloc only recomputes totalRealizedPnl/
//     totalUnrealizedPnl/totalPnl/totalMTM inside its own tick handler --
//     never on a plain position update -- so all three totals sit
//     unresolved until the *first* synthetic tick lands, which depends on
//     the app's ~1/sec timer and the subscription-manager plumbing
//     catching up. Tests poll rather than use a fixed sleep to avoid
//     depending on that latency.
//   - None of the demo positions seed a realized gain, so the realised
//     total settles at "0.0" (formatWithPrecision's own sign is omitted
//     for exactly zero) once that first tick lands.
//   - There's no dedicated close button -- same re-tap-the-drawer-tab
//     mechanism as the Top Options panel. Asserting open/closed state via
//     `find.text('P&L')` is unreliable: the drawer's own collapsed tab
//     rail renders a "P&L" label under its icon regardless of whether the
//     popup is open, so `ChartTestKeys.plTotalValue` (only present inside
//     the open panel) is used instead.

Future<String?> _pollForRealisedText(PatrolIntegrationTester $) async {
  final finder = find.byKey(Key(ChartTestKeys.plRealisedValue));
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  String? text;
  while (DateTime.now().isBefore(deadline)) {
    await $.tester.pump(const Duration(milliseconds: 500));
    text = $.tester.widget<Text>(finder).data;
    if (text == '0.0') break;
  }

  return text;
}

void main() {
  group('P&L — panel', () {
    patrolTest('opens with all three P&L totals rendering', ($) async {
      await openChartAndAwaitLoad($);
      await openPlPanel($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.byKey(Key(ChartTestKeys.plTotalValue)), findsOneWidget);
      expect(find.byKey(Key(ChartTestKeys.plRealisedValue)), findsOneWidget);
      expect(find.byKey(Key(ChartTestKeys.plUnrealisedValue)), findsOneWidget);

      await closePlPanel($);
    });

    patrolTest("shows the seeded positions' realised P&L", ($) async {
      await openChartAndAwaitLoad($);
      await openPlPanel($);

      final realisedText = await _pollForRealisedText($);
      expect(realisedText, '0.0');

      await closePlPanel($);
    });

    patrolTest('tapping the same drawer tab again closes the panel', ($) async {
      await openChartAndAwaitLoad($);
      await openPlPanel($);

      expect(find.byKey(Key(ChartTestKeys.plTotalValue)), findsOneWidget);

      await closePlPanel($);

      expect(find.byKey(Key(ChartTestKeys.plTotalValue)), findsNothing);
    });
  });
}
