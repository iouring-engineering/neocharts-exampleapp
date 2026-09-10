import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'helpers.dart';

void main() {
  group('Interval switching', () {
    patrolTest('switches from 1m to 5m — intervalBtn label updates', ($) async {
      await openChartAndAwaitLoad($);

      // Debug overlay must be present in debug builds.
      expect($(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
      expect($(Key(ChartTestKeys.debugZoomLevel)), findsOneWidget);

      await openIntervalMenu($);
      await tapIntervalChip($, 'min5');
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      // App bar interval button must reflect the new selection.
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('5m'),
        ),
        findsOneWidget,
      );
      // Debug overlay must survive the data reload.
      expect($(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
    });

    patrolTest('switches from 5m to 1h — intervalBtn label updates', ($) async {
      await openChartAndAwaitLoad($);

      // Move to 5m first so this test is not order-dependent.
      await openIntervalMenu($);
      await tapIntervalChip($, 'min5');
      await $.pumpAndSettle();
      await awaitDataReload($);

      await openIntervalMenu($);
      await tapIntervalChip($, 'hour1');
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('1h'),
        ),
        findsOneWidget,
      );
      expect($(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
    });

    patrolTest('switches to daily (1D) — intervalBtn label updates', ($) async {
      await openChartAndAwaitLoad($);

      await openIntervalMenu($);
      await tapIntervalChip($, 'day1');
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
      // Zoom level debug key is always rendered alongside visible range.
      expect($(Key(ChartTestKeys.debugZoomLevel)), findsOneWidget);
    });

    patrolTest('repeated interval changes do not produce error state', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      const sequence = ['min5', 'min15', 'hour1', 'min1'];
      for (final name in sequence) {
        await openIntervalMenu($);
        await tapIntervalChip($, name);
        await $.pumpAndSettle();
        await awaitDataReload($);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      }

      // After returning to 1m the button must show '1m'.
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('1m'),
        ),
        findsOneWidget,
      );
    });
  });
}
