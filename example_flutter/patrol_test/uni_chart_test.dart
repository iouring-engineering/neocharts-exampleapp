import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/enums/chart_type.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// UniChart (`NxtChartPage.uni`): one chart under a compact toolbar, with a
// collapsible drawing rail floating over it, opened here from its home card
// (UniChartScreen: symbol app bar + Buy / Sell bar).

// Tooltips of the rail buttons these tests use (English l10n strings).
const _linesTooltip = 'Lines & Channels';
const _trendLine = 'Trend Line';

final _expandBtn = find.byKey(const Key(ChartTestKeys.uniRailExpandBtn));
final _collapseBtn = find.byKey(const Key(ChartTestKeys.uniRailCollapseBtn));

Future<void> _expandRail(PatrolIntegrationTester $) async {
  await $.tester.tap(_expandBtn);
  await $.pumpAndSettle();
}

// Opens [tooltip]'s options from the bar on its button's right edge.
Future<void> _openRailOptions(PatrolIntegrationTester $, String tooltip) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.railFlyoutBar(tooltip))));
  await $.pumpAndSettle();
}

void main() {
  group('UniChart', () {
    patrolTest('shows the symbol, Buy and Sell, and the compact toolbar', (
      $,
    ) async {
      await openUniChartAndAwaitLoad($);

      expect(find.text('DRREDDY'), findsOneWidget);
      expect(find.text('Buy'), findsOneWidget);
      expect(find.text('Sell'), findsOneWidget);
      expect(
        find.byKey(const Key(ChartTestKeys.uniChartTypesBtn)),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key(ChartTestKeys.uniIndicatorsBtn)),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key(ChartTestKeys.uniRefreshBtn)),
        findsOneWidget,
      );
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('chart type button opens the chart types, not the full menu', (
      $,
    ) async {
      await openUniChartAndAwaitLoad($);

      await $.tester.tap(find.byKey(const Key(ChartTestKeys.uniChartTypesBtn)));
      await $.pumpAndSettle();

      expect(find.byKey(Key(ChartTestKeys.menuRailChartTypes)), findsOneWidget);
      expect(find.byKey(Key(ChartTestKeys.menuRailIntervals)), findsOneWidget);
      expect(find.byKey(Key(ChartTestKeys.menuRailIndicators)), findsOneWidget);
      // Drawing tools live in the floating rail, and layout / order prefs
      // aren't part of UniChart.
      expect(find.byKey(Key(ChartTestKeys.menuRailLayout)), findsNothing);
      expect(find.byKey(Key(ChartTestKeys.menuRailOrderPrefs)), findsNothing);
    });

    patrolTest('picking a chart type keeps the chart healthy', ($) async {
      await openUniChartAndAwaitLoad($);

      await $.tester.tap(find.byKey(const Key(ChartTestKeys.uniChartTypesBtn)));
      await $.pumpAndSettle();
      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.chartTypeRow(ChartType.line.name))),
      );
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    group('floating drawing rail', () {
      patrolTest('starts collapsed, expands and collapses with its chevrons', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        expect(_expandBtn, findsOneWidget);
        expect(_collapseBtn, findsNothing);

        await _expandRail($);
        expect(_expandBtn, findsNothing);
        expect(_collapseBtn, findsOneWidget);

        await $.tester.tap(_collapseBtn);
        await $.pumpAndSettle();
        expect(_expandBtn, findsOneWidget);
        expect(_collapseBtn, findsNothing);
      });

      patrolTest('tapping outside the rail collapses it', ($) async {
        await openUniChartAndAwaitLoad($);
        await _expandRail($);

        // The app bar's symbol title is well outside the rail.
        await $.tester.tap(find.text('DRREDDY'));
        await $.pumpAndSettle();

        expect(_collapseBtn, findsNothing);
        expect(_expandBtn, findsOneWidget);
      });

      patrolTest('a button\'s bar opens its options without collapsing', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        await _expandRail($);

        await _openRailOptions($, _linesTooltip);

        expect(find.text(_trendLine), findsOneWidget);
        expect(_collapseBtn, findsOneWidget);
      });

      patrolTest('picking a tool closes the options and the rail', ($) async {
        await openUniChartAndAwaitLoad($);
        await _expandRail($);
        await _openRailOptions($, _linesTooltip);

        await $.tester.tap(find.text(_trendLine));
        await $.pumpAndSettle();

        expect(find.text(_trendLine), findsNothing);
        expect(_collapseBtn, findsNothing);
        expect(_expandBtn, findsOneWidget);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      });

      patrolTest('tapping inside the open options does not collapse', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        await _expandRail($);
        await _openRailOptions($, _linesTooltip);

        // A section header is inside the options but isn't a tool.
        await $.tester.tap(find.text('LINES'));
        await $.pumpAndSettle();

        expect(_collapseBtn, findsOneWidget);
      });

      patrolTest('the collapsed rail can be reopened after a tool pick', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        await _expandRail($);
        await _openRailOptions($, _linesTooltip);
        await $.tester.tap(find.text(_trendLine));
        await $.pumpAndSettle();

        await _expandRail($);

        expect(_collapseBtn, findsOneWidget);
        expect(find.byTooltip(_linesTooltip), findsOneWidget);
      });
    });
  });
}
