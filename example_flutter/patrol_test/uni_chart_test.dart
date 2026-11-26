import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:nxtchart/src/enums/chart_type.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';
import 'positions/positions_test_helpers.dart';

// UniChart (`NeoChartPage.uni`): one chart under a compact toolbar, with a
// floating drawing-tools button over it that opens a toolbar across the
// chart's top, opened here from its home card (UniChartScreen: symbol app
// bar + Buy / Sell bar).

// Tooltip of the toolbar group these tests use (English l10n strings).
const _linesTooltip = 'Lines & Channels';
const _trendLine = 'Trend Line';

final _panelBtn = find.byKey(const Key(ChartTestKeys.drawToolsPanelBtn));
final _closeBtn = find.byKey(const Key(ChartTestKeys.drawingToolbarCloseBtn));

Future<void> _openToolbar(PatrolIntegrationTester $) async {
  await $.tester.tap(_panelBtn);
  await $.pumpAndSettle();
}

// Opens UniChart on a fresh mock and seeds one long 75-lot position, whose
// tag sits at the last price (see [openChartWithMockPosition]).
Future<void> _openWithPosition(PatrolIntegrationTester $) async {
  final mock = NeoChartsRepository(storageKey: 'uni_chart');
  await openChartAndAwaitLoad($, hostOverride: mock, cardTitle: 'UniChart');
  mock.seedPosition();
}

// Opens [tooltip]'s options from the chevron beside its button (the
// button and its chevron share the tooltip; the chevron comes last).
Future<void> _openOptions(PatrolIntegrationTester $, String tooltip) async {
  await $.tester.tap(find.byTooltip(tooltip).last);
  await $.pumpAndSettle();
}

void main() {
  group('UniChart', () {
    patrolTest('shows the symbol, Buy and Sell, and the compact toolbar', (
      $,
    ) async {
      await openUniChartAndAwaitLoad($);

      expect(find.text('NIFTY'), findsOneWidget);
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
      // Drawing tools live behind the floating button, and layout / order prefs
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

    group('floating drawing tools button', () {
      patrolTest('opens the toolbar, whose close button brings it back', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        expect(_panelBtn, findsOneWidget);
        expect(_closeBtn, findsNothing);

        await _openToolbar($);
        expect(_panelBtn, findsNothing);
        expect(_closeBtn, findsOneWidget);

        await $.tester.tap(_closeBtn);
        await $.pumpAndSettle();
        expect(_panelBtn, findsOneWidget);
        expect(_closeBtn, findsNothing);
      });

      patrolTest('a group\'s chevron opens its options, toolbar stays open', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        await _openToolbar($);

        await _openOptions($, _linesTooltip);

        expect(find.text(_trendLine), findsOneWidget);
        expect(_closeBtn, findsOneWidget);
      });

      patrolTest('picking a tool closes the options and the toolbar', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        await _openToolbar($);
        await _openOptions($, _linesTooltip);

        await $.tester.tap(find.text(_trendLine));
        await $.pumpAndSettle();

        expect(find.text(_trendLine), findsNothing);
        expect(_closeBtn, findsNothing);
        expect(_panelBtn, findsOneWidget);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      });

      patrolTest('tapping inside the open options keeps the toolbar', (
        $,
      ) async {
        await openUniChartAndAwaitLoad($);
        await _openToolbar($);
        await _openOptions($, _linesTooltip);

        // A section header is inside the options but isn't a tool.
        await $.tester.tap(find.text('LINES'));
        await $.pumpAndSettle();

        expect(_closeBtn, findsOneWidget);
      });

      patrolTest('the toolbar can be reopened after a tool pick', ($) async {
        await openUniChartAndAwaitLoad($);
        await _openToolbar($);
        await _openOptions($, _linesTooltip);
        await $.tester.tap(find.text(_trendLine));
        await $.pumpAndSettle();

        await _openToolbar($);

        expect(_closeBtn, findsOneWidget);
        expect(find.byTooltip(_linesTooltip), findsNWidgets(2));
      });
    });

    // UniChart opens no SDK pads: each action reaches the host's on*
    // callback, which the example reports in a snackbar.
    group('host callbacks', () {
      patrolTest('exiting a position is a host market order', ($) async {
        await _openWithPosition($);
        final tag = find.byKey(Key(ChartTestKeys.positionTag(positionId)));
        await waitUntilPresent($, tag);
        await $.tester.tap(
          find
              .descendant(of: tag, matching: find.byType(GestureDetector))
              .first,
        );
        await $.pumpAndSettle();

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.positionExitBtn(positionId))),
        );
        await $.pumpAndSettle();

        expect(find.text('onTrade: Sell market qty 75 normal'), findsOneWidget);
      });

      patrolTest('dragging a position SL is a host stop order', ($) async {
        await _openWithPosition($);

        await dragPositionHandle($, isSL: true);

        expect(
          find.textContaining('onTrade: Sell stopmarket @'),
          findsOneWidget,
        );
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      });
    });
  });
}
