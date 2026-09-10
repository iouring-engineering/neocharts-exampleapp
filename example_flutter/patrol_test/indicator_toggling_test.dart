import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'helpers.dart';

// Legend row key flow:
//   - Tap legendRow(key)  → expands the row, revealing toggle/delete buttons.
//   - Tap legendToggleBtn(key) → toggles visibility.
//   - Tap legendDeleteBtn(key) → removes the indicator.
//
// Active indicators view:
//   - indicatorActiveRow(key) is a row whose own tap removes the indicator.

void main() {
  group('Indicator toggling — overlay (SMA)', () {
    patrolTest('add SMA — legend row and active row appear', ($) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
      await $.pumpAndSettle();

      // Legend row must appear (main-panel legend, overlay section).
      expect($(Key(ChartTestKeys.legendRow('sma'))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      // Navigate to active indicators view and verify the entry is there.
      await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
      await $.pumpAndSettle();
      expect($(Key(ChartTestKeys.indicatorActiveRow('sma'))), findsOneWidget);
    });

    patrolTest(
      'toggle SMA visibility — indicator stays in active list while hidden',
      ($) async {
        await openChartAndAwaitLoad($);

        await openIndicatorMenu($);
        await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
        await $.pumpAndSettle();

        // Expand the legend row to reveal the toggle button.
        await $(Key(ChartTestKeys.legendRow('sma'))).tap();
        await $.pumpAndSettle();

        await $(Key(ChartTestKeys.legendToggleBtn('sma'))).tap();
        await $.pumpAndSettle();

        // Indicator is hidden but still in the active list (legend row for
        // a hidden overlay moves into the main-panel legend's hidden
        // section, so the key is still present in the tree).
        expect($(Key(ChartTestKeys.legendRow('sma'))), findsOneWidget);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        // Verify it is still in the active indicators view.
        await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
        await $.pumpAndSettle();
        expect($(Key(ChartTestKeys.indicatorActiveRow('sma'))), findsOneWidget);
      },
    );

    patrolTest(
      'remove SMA via legend delete — legend row and active row disappear',
      ($) async {
        await openChartAndAwaitLoad($);

        await openIndicatorMenu($);
        await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
        await $.pumpAndSettle();

        // Expand then delete.
        await $(Key(ChartTestKeys.legendRow('sma'))).tap();
        await $.pumpAndSettle();
        await $(Key(ChartTestKeys.legendDeleteBtn('sma'))).tap();
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.legendRow('sma'))), findsNothing);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      },
    );

    patrolTest('remove SMA via active indicators view', ($) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
      await $.pumpAndSettle();

      // Navigate to active view and tap the row to remove it.
      await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorActiveRow('sma'))).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.indicatorActiveRow('sma'))), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Indicator toggling — panel (RSI)', () {
    patrolTest('add RSI — legend row appears in sub-panel area', ($) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      // Switch to the Sub-chart / panel tab for clarity.
      await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorBrowseRow('rsi'))).tap();
      await $.pumpAndSettle();

      // Panel indicators are positioned directly in the Stack overlay.
      expect($(Key(ChartTestKeys.legendRow('rsi'))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('toggle RSI visibility — legend row persists (marked hidden)', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorBrowseRow('rsi'))).tap();
      await $.pumpAndSettle();

      // Expand the panel legend row then toggle visibility.
      await $(Key(ChartTestKeys.legendRow('rsi'))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.legendToggleBtn('rsi'))).tap();
      await $.pumpAndSettle();

      // When a panel indicator is hidden it moves to the main-panel
      // legend's hidden section; its legendRow key stays in the tree.
      expect($(Key(ChartTestKeys.legendRow('rsi'))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('remove RSI via legend delete — legend row disappears', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorBrowseRow('rsi'))).tap();
      await $.pumpAndSettle();

      await $(Key(ChartTestKeys.legendRow('rsi'))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.legendDeleteBtn('rsi'))).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.legendRow('rsi'))), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Indicator toggling — multiple indicators', () {
    patrolTest('add SMA + RSI simultaneously — both legend rows visible', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
      await $.pumpAndSettle();

      await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorBrowseRow('rsi'))).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.legendRow('sma'))), findsOneWidget);
      expect($(Key(ChartTestKeys.legendRow('rsi'))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      // Active view must list both.
      await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
      await $.pumpAndSettle();
      expect($(Key(ChartTestKeys.indicatorActiveRow('sma'))), findsOneWidget);
      expect($(Key(ChartTestKeys.indicatorActiveRow('rsi'))), findsOneWidget);
    });

    patrolTest('indicators survive an interval change without disappearing', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      // Add SMA.
      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
      await $.pumpAndSettle();
      await closeMenu($);

      // Change interval.
      await openIntervalMenu($);
      await $(Key(ChartTestKeys.intervalChip('min5'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      // Legend row must still be present after reload.
      expect($(Key(ChartTestKeys.legendRow('sma'))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect($(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
    });
  });
}
