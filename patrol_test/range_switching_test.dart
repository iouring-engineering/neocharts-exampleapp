import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'helpers.dart';

// ChartRange's default-interval mapping:
//   day1   → min1  → '1m'
//   day5   → min5  → '5m'
//   month1 → min30 → '30m'
//   month3 → min30 → '30m'
//   year1  → day1  → '1D'
//   year5  → day1  → '1D'

void main() {
  group('Range (timeframe) switching', () {
    patrolTest('1D range auto-sets interval to 1m', ($) async {
      await openChartAndAwaitLoad($);

      await openIntervalMenu($);
      await $(Key(ChartTestKeys.rangeChip('day1'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('1m'),
        ),
        findsOneWidget,
      );
      expect($(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
    });

    patrolTest('5D range auto-sets interval to 5m', ($) async {
      await openChartAndAwaitLoad($);

      await openIntervalMenu($);
      await $(Key(ChartTestKeys.rangeChip('day5'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('5m'),
        ),
        findsOneWidget,
      );
      expect($(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
    });

    patrolTest('1M range auto-sets interval to 30m', ($) async {
      await openChartAndAwaitLoad($);

      await openIntervalMenu($);
      await $(Key(ChartTestKeys.rangeChip('month1'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('30m'),
        ),
        findsOneWidget,
      );
    });

    patrolTest('1Y range auto-sets interval to 1D', ($) async {
      await openChartAndAwaitLoad($);

      await openIntervalMenu($);
      await $(Key(ChartTestKeys.rangeChip('year1'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('1D'),
        ),
        findsOneWidget,
      );
      expect($(Key(ChartTestKeys.debugZoomLevel)), findsOneWidget);
    });

    patrolTest(
      'switching between multiple ranges does not produce error state',
      ($) async {
        await openChartAndAwaitLoad($);

        const ranges = ['day1', 'day5', 'month3', 'year1', 'day1'];
        for (final name in ranges) {
          await openIntervalMenu($);
          await $(Key(ChartTestKeys.rangeChip(name))).tap();
          await $.pumpAndSettle();
          await awaitDataReload($);
          expect($(Key(ChartTestKeys.errorState)), findsNothing);
        }

        // After landing back on day1, interval must be 1m.
        expect(
          find.descendant(
            of: find.byKey(Key(ChartTestKeys.intervalBtn)),
            matching: find.text('1m'),
          ),
          findsOneWidget,
        );
      },
    );

    patrolTest('manual interval selection after range clears range selection', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      // Pick a range first.
      await openIntervalMenu($);
      await $(Key(ChartTestKeys.rangeChip('day5'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      // Now pick a different manual interval — should override the range.
      await openIntervalMenu($);
      await $(Key(ChartTestKeys.intervalChip('hour4'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('4h'),
        ),
        findsOneWidget,
      );
    });
  });
}
