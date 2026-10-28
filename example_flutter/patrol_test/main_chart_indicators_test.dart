import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/enums/chart_indicator.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// Main Chart (overlay) indicators: the "Main Chart" tab of the indicator
// browser, and the add / multi-instance / hide / remove lifecycle of every
// overlay indicator the picker offers.
//
// The browser rows live in a lazy ListView, so a row below the fold is not
// built. Every lookup scrolls the list to the row instead of using the search
// field: focusing the field opens the on-screen keypad, which covers the list.

/// Overlay indicators the picker offers for a plain (non-option) symbol.
final _overlays = ChartIndicator.values
    .where((i) => i.type == IndicatorType.overlay && i.isAvailableFor(null))
    .toList();

Future<void> _openMainChartTab(PatrolIntegrationTester $) async {
  await openIndicatorMenu($);
  await $(Key(ChartTestKeys.indicatorTabOverlay)).tap();
  await $.pumpAndSettle();
}

Finder _legendRow(String instanceId) =>
    find.byKey(Key(ChartTestKeys.legendRow(instanceId)));

Finder _activeRow(String instanceId) =>
    find.byKey(Key(ChartTestKeys.indicatorActiveRow(instanceId)));

// Scrolls to [i]'s row on the Main Chart tab and taps it.
Future<void> _add(PatrolIntegrationTester $, ChartIndicator i) =>
    tapIndicatorRow($, i);

Future<void> _openActive(PatrolIntegrationTester $) async {
  await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
  await $.pumpAndSettle();
}

Future<void> _backToBrowser(PatrolIntegrationTester $) async {
  await $(Key(ChartTestKeys.indicatorBackBtn)).tap();
  await $.pumpAndSettle();
}

void main() {
  ignorePlatformSemanticsChanges();

  group('Main chart indicators — browser tab', () {
    patrolTest('Main Chart tab count matches the overlay indicators', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      final count = ChartIndicator.values
          .where((i) => i.type == IndicatorType.overlay)
          .length;

      expect(find.textContaining('($count)'), findsWidgets);
      expect(
        find.byKey(Key(ChartTestKeys.indicatorTabOverlay)),
        findsOneWidget,
      );
    });

    patrolTest('every overlay indicator row can be scrolled to', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      final missing = <String>[];
      for (final i in _overlays) {
        try {
          await revealIndicatorRow($, i);
        } on Object catch (e) {
          final msg = e.toString().split('\n').first;
          missing.add('${i.key} ($msg)');
        }
      }

      expect(missing, isEmpty, reason: 'rows not reachable on Main Chart tab');
    });

    patrolTest('Main Chart tab does not list panel indicators', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      // Scroll the whole list; a panel row would be built on the way.
      for (var n = 0; n < 40; n++) {
        await $.tester.drag(indicatorBrowserList, const Offset(0, -300));
        await $.pump();
        expect(
          find.byKey(Key(ChartTestKeys.indicatorBrowseRow('rsi'))),
          findsNothing,
        );
        expect(
          find.byKey(Key(ChartTestKeys.indicatorBrowseRow('macd'))),
          findsNothing,
        );
      }
    });
  });

  group('Main chart indicators — add and remove', () {
    patrolTest('every overlay indicator can be added and removed', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      final failures = <String>[];
      for (final i in _overlays) {
        try {
          await _add($, i);

          if (_legendRow(i.key).evaluate().isEmpty) {
            failures.add('${i.key}: no legend row after add');
          }
          if (find.byKey(Key(ChartTestKeys.errorState)).evaluate().isNotEmpty) {
            failures.add('${i.key}: error state after add');
          }

          // Remove through the active view so the next indicator starts
          // from a clean chart.
          await _openActive($);
          if (_activeRow(i.key).evaluate().isEmpty) {
            failures.add('${i.key}: no active row after add');
          } else {
            await $(Key(ChartTestKeys.indicatorActiveRow(i.key))).tap();
            await $.pumpAndSettle();
            if (_activeRow(i.key).evaluate().isNotEmpty) {
              failures.add('${i.key}: active row remains after remove');
            }
          }
          await _backToBrowser($);

          if (_legendRow(i.key).evaluate().isNotEmpty) {
            failures.add('${i.key}: legend row remains after remove');
          }
        } on Object catch (e) {
          failures.add('${i.key}: $e');
          // Get back to a known state for the next indicator.
          await $.tester.pump();
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    patrolTest('added overlay appears in the active indicators view', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      await _add($, ChartIndicator.ema);
      await _openActive($);

      expect(_activeRow(ChartIndicator.ema.key), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Main chart indicators — multiple instances', () {
    patrolTest('allowMultiple overlay adds a second instance', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      await _add($, ChartIndicator.sma);
      await _add($, ChartIndicator.sma);

      expect(_legendRow(ChartIndicator.sma.key), findsOneWidget);
      expect(_legendRow('${ChartIndicator.sma.key}_2'), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await _openActive($);
      expect(_activeRow(ChartIndicator.sma.key), findsOneWidget);
      expect(_activeRow('${ChartIndicator.sma.key}_2'), findsOneWidget);
    });

    patrolTest('removing the first instance keeps the second', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      await _add($, ChartIndicator.sma);
      await _add($, ChartIndicator.sma);

      await _openActive($);
      await $(Key(ChartTestKeys.indicatorActiveRow(ChartIndicator.sma.key)))
          .tap();
      await $.pumpAndSettle();

      expect(_activeRow(ChartIndicator.sma.key), findsNothing);
      expect(_activeRow('${ChartIndicator.sma.key}_2'), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('single-instance overlay is not added twice', ($) async {
      final single = _overlays.firstWhere((i) => !i.allowMultiple);
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      await _add($, single);
      await revealIndicatorRow($, single);
      await $(Key(ChartTestKeys.indicatorBrowseRow(single.key))).tap();
      await $.pumpAndSettle();

      expect(_legendRow(single.key), findsOneWidget);
      expect(_legendRow('${single.key}_2'), findsNothing);
    });

    patrolTest('different overlays can be shown together', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);

      await _add($, ChartIndicator.sma);
      await _add($, ChartIndicator.ema);
      await _add($, ChartIndicator.bb);

      expect(_legendRow(ChartIndicator.sma.key), findsOneWidget);
      expect(_legendRow(ChartIndicator.ema.key), findsOneWidget);
      expect(_legendRow(ChartIndicator.bb.key), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Main chart indicators — legend and persistence', () {
    patrolTest('band overlay can be hidden and stays in the active list', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);
      await _add($, ChartIndicator.bb);
      await closeMenu($);

      await $(Key(ChartTestKeys.legendRow(ChartIndicator.bb.key))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.legendToggleBtn(ChartIndicator.bb.key))).tap();
      await $.pumpAndSettle();

      expect(_legendRow(ChartIndicator.bb.key), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      // The Active view lives in the menu, which was closed above.
      await openIndicatorMenu($);
      await _openActive($);
      expect(_activeRow(ChartIndicator.bb.key), findsOneWidget);
    });

    patrolTest('overlay can be removed from the legend', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);
      await _add($, ChartIndicator.ema);
      await closeMenu($);

      await $(Key(ChartTestKeys.legendRow(ChartIndicator.ema.key))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.legendDeleteBtn(ChartIndicator.ema.key))).tap();
      await $.pumpAndSettle();

      expect(_legendRow(ChartIndicator.ema.key), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('overlays survive an interval change', ($) async {
      await openChartAndAwaitLoad($);
      await _openMainChartTab($);
      await _add($, ChartIndicator.sma);
      await _add($, ChartIndicator.bb);
      await closeMenu($);

      await openIntervalMenu($);
      await $(Key(ChartTestKeys.intervalChip('min5'))).tap();
      await $.pumpAndSettle();
      await awaitDataReload($);

      expect(_legendRow(ChartIndicator.sma.key), findsOneWidget);
      expect(_legendRow(ChartIndicator.bb.key), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });
}
