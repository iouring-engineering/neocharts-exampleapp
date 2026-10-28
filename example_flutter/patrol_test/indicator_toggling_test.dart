import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/enums/chart_indicator.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// Legend row key flow (the chart menu must be closed first -- its popup sits
// under a full-screen barrier that covers the legend):
//   - Tap legendRow(id)  → expands the row, revealing toggle/delete buttons.
//   - Tap legendToggleBtn(id) → toggles visibility.
//   - Tap legendDeleteBtn(id) → removes the indicator.
//
// Active indicators view:
//   - indicatorActiveRow(id) is a row whose own tap removes the indicator.
//
// Keys are built from ChartIndicator.key (e.g. 'v-sma'), never hardcoded.

final _sma = ChartIndicator.sma.key;
final _rsi = ChartIndicator.rsi.key;

// Taps a Main Chart tab row (the default tab is "All", whose rows are far
// down a lazy list).
Future<void> _addOverlay(
  PatrolIntegrationTester $,
  ChartIndicator indicator,
) async {
  await $(Key(ChartTestKeys.indicatorTabOverlay)).tap();
  await $.pumpAndSettle();
  await tapIndicatorRow($, indicator);
}

Future<void> _addPanel(
  PatrolIntegrationTester $,
  ChartIndicator indicator,
) async {
  await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
  await $.pumpAndSettle();
  await tapIndicatorRow($, indicator);
}

void main() {
  ignorePlatformSemanticsChanges();

  group('Indicator toggling — overlay (SMA)', () {
    patrolTest('add SMA — legend row and active row appear', ($) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await _addOverlay($, ChartIndicator.sma);

      // Legend row must appear (main-panel legend, overlay section).
      expect($(Key(ChartTestKeys.legendRow(_sma))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      // Navigate to active indicators view and verify the entry is there.
      await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
      await $.pumpAndSettle();
      expect($(Key(ChartTestKeys.indicatorActiveRow(_sma))), findsOneWidget);
    });

    patrolTest(
      'toggle SMA visibility — indicator stays in active list while hidden',
      ($) async {
        await openChartAndAwaitLoad($);

        await openIndicatorMenu($);
        await _addOverlay($, ChartIndicator.sma);
        await closeMenu($);

        // Expand the legend row to reveal the toggle button.
        await $(Key(ChartTestKeys.legendRow(_sma))).tap();
        await $.pumpAndSettle();

        await $(Key(ChartTestKeys.legendToggleBtn(_sma))).tap();
        await $.pumpAndSettle();

        // Indicator is hidden but still in the active list (legend row for
        // a hidden overlay moves into the main-panel legend's hidden
        // section, so the key is still present in the tree).
        expect($(Key(ChartTestKeys.legendRow(_sma))), findsOneWidget);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        // Verify it is still in the active indicators view (reopen the menu
        // that was closed above).
        await openIndicatorMenu($);
        await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
        await $.pumpAndSettle();
        expect($(Key(ChartTestKeys.indicatorActiveRow(_sma))), findsOneWidget);
      },
      tags: ['legend_toggle'],
    );

    patrolTest('remove SMA via legend delete — legend row disappears', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await _addOverlay($, ChartIndicator.sma);
      await closeMenu($);

      // Expand then delete.
      await $(Key(ChartTestKeys.legendRow(_sma))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.legendDeleteBtn(_sma))).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.legendRow(_sma))), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    }, tags: ['legend_delete']);

    patrolTest('remove SMA via active indicators view', ($) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await _addOverlay($, ChartIndicator.sma);

      // Navigate to active view and tap the row to remove it.
      await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorActiveRow(_sma))).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.indicatorActiveRow(_sma))), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Indicator toggling — panel (RSI)', () {
    patrolTest('add RSI — legend row appears in sub-panel area', ($) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await _addPanel($, ChartIndicator.rsi);

      // Panel indicators are positioned directly in the Stack overlay.
      expect($(Key(ChartTestKeys.legendRow(_rsi))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('toggle RSI visibility — legend row persists (marked hidden)', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await _addPanel($, ChartIndicator.rsi);
      await closeMenu($);

      // Expand the panel legend row then toggle visibility.
      await $(Key(ChartTestKeys.legendRow(_rsi))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.legendToggleBtn(_rsi))).tap();
      await $.pumpAndSettle();

      // When a panel indicator is hidden it moves to the main-panel
      // legend's hidden section; its legendRow key stays in the tree.
      expect($(Key(ChartTestKeys.legendRow(_rsi))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    }, tags: ['legend_toggle']);

    patrolTest('remove RSI via legend delete — legend row disappears', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await _addPanel($, ChartIndicator.rsi);
      await closeMenu($);

      await $(Key(ChartTestKeys.legendRow(_rsi))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.legendDeleteBtn(_rsi))).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.legendRow(_rsi))), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    }, tags: ['legend_delete']);
  });

  group('Indicator toggling — multiple indicators', () {
    patrolTest('add SMA + RSI simultaneously — both legend rows visible', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openIndicatorMenu($);
      await _addOverlay($, ChartIndicator.sma);
      await _addPanel($, ChartIndicator.rsi);

      expect($(Key(ChartTestKeys.legendRow(_sma))), findsOneWidget);
      expect($(Key(ChartTestKeys.legendRow(_rsi))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      // Active view must list both.
      await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
      await $.pumpAndSettle();
      expect($(Key(ChartTestKeys.indicatorActiveRow(_sma))), findsOneWidget);
      expect($(Key(ChartTestKeys.indicatorActiveRow(_rsi))), findsOneWidget);
    });

    patrolTest('indicators survive an interval change without disappearing', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      // Add SMA.
      await openIndicatorMenu($);
      await _addOverlay($, ChartIndicator.sma);
      await closeMenu($);

      // Change interval.
      await openIntervalMenu($);
      await $(Key(ChartTestKeys.intervalChip('min5'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      // Legend row must still be present after reload.
      expect($(Key(ChartTestKeys.legendRow(_sma))), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect($(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
    });
  });
}
