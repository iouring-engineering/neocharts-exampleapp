import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// Top 5 Options panel:
//   - NxtChartRepository.chartTopOptions returns the top-volume strikes, so
//     the list is meant to render real content by default -- not just the
//     "No data available" empty state.
//   - marketDataStreamer emits synthetic per-symbol ticks for whichever
//     option symbols are currently subscribed, so live values populate once
//     the panel opens.
//   - There's no dedicated close button -- tapping the already-open drawer
//     tab again closes the popup; `closeTopOptionsPanel` exercises that path.
//
// KNOWN-OPEN: as of this port, the panel's content does not actually render
// after opening (the "Top 5 Options" text and PE/CE tabs are never found in
// the tree). Root cause not yet confirmed -- ruled out so far: a data-shape
// mismatch in chartTopOptions's response, and a localization-delegate
// registration gap. The assertions below describe the intended behavior,
// not currently-passing behavior.

void main() {
  group('Top Options — panel', () {
    patrolTest('opens with the CALL list rendering real data by default', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await openTopOptionsPanel($);

      expect($(const Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.text('Top 5 Options'), findsOneWidget);
      expect(find.text('No data available'), findsNothing);

      await closeTopOptionsPanel($);
    });

    patrolTest('switching to PUT shows the put list without error', ($) async {
      await openChartAndAwaitLoad($);
      await openTopOptionsPanel($);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.topOptionsTypeTab('PE'))),
      );
      await $.pumpAndSettle();

      expect($(const Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.text('No data available'), findsNothing);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.topOptionsTypeTab('CE'))),
      );
      await $.pumpAndSettle();

      expect($(const Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.text('No data available'), findsNothing);

      await closeTopOptionsPanel($);
    });

    patrolTest('tapping the same drawer tab again closes the panel', ($) async {
      await openChartAndAwaitLoad($);
      await openTopOptionsPanel($);

      expect(find.text('Top 5 Options'), findsOneWidget);

      await closeTopOptionsPanel($);

      expect(find.text('Top 5 Options'), findsNothing);
    });
  });
}
