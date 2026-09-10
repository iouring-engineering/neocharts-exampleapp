import 'package:financial_chart/financial_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/chart_type.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:nxtchart/src/shared/constants.dart';

import 'helpers.dart';

// Real-world repro flow for chart type switching: open the indexCallPut
// layout, open the chart-type menu from the RIGHT-hand panel (the ATM
// CE-PE chart), and pick a type there -- this is the exact path that
// drives the chart bloc's selected chart type.
//
// Candle width itself is computed by a pure function that scales width
// from each bar's traded volume -- including the case of an index symbol,
// which has no traded volume, so every candle renders at a uniform width
// instead of dividing by zero. That's covered directly (higher volume ->
// wider bar, all-zero volume -> uniform max width, no divide-by-zero) by
// the charting engine's own unit tests -- Patrol/widget tests can't
// inspect a CustomPainter's rendered pixel widths, so this file sticks to
// what it CAN verify: that selecting the row actually updates the bloc's
// selected type.

// Verifies the RIGHT panel's actual live GChart -- not the picker's
// selection -- has switched to render [type]: mirrors exactly what the
// chart bloc sets on the real graph objects, so this fails if the chart
// itself silently didn't follow the selection.
void _expectRenderedChartType(GChart chart, ChartType type) {
  final panel = chart.findPanelByID(Constants.mainPanel)!;
  final ohlc = panel.findGraphById(Constants.ohlcGraph)! as GGraphOhlc;
  final line = panel.findGraphById(Constants.lineGraph)!;
  final area = panel.findGraphById(Constants.areaGraph)!;
  final ha = panel.findGraphById(Constants.haGraph)!;

  expect(
    ohlc.visible,
    type.usesOhlcGraph,
    reason: 'OHLC graph visibility for $type',
  );
  expect(line.visible, type == ChartType.line, reason: 'line graph for $type');
  expect(area.visible, type == ChartType.area, reason: 'area graph for $type');
  expect(
    ha.visible,
    type == ChartType.heikinAshi,
    reason: 'Heikin Ashi graph for $type',
  );

  if (type.usesOhlcGraph) {
    expect(
      ohlc.drawAsCandle,
      type.drawAsCandle,
      reason: 'drawAsCandle for $type',
    );
    expect(
      ohlc.volumeScaledWidth,
      type.scalesWidthByVolume,
      reason: 'volumeScaledWidth for $type',
    );
  }
}

void main() {
  group('Chart type switching — rendered chart matches selection', () {
    for (final type in ChartType.values) {
      patrolTest(
        'selecting ${type.name} renders the correct graph on the actual '
        'chart, even after the menu is closed',
        ($) async {
          await openChartAndAwaitLoad($);
          await selectChartLayout($, 'indexCallPut');

          await openChartTypeMenuRightPanel($);
          await tapChartTypeRow($, type.name);
          await $.pumpAndSettle();

          // Right after selecting, while the menu is still open.
          _expectRenderedChartType(currentChartRightPanel($), type);

          await closeChartTypeMenuRightPanel($);
          expect($(Key(ChartTestKeys.errorState)), findsNothing);

          // The real assertion: with the picker gone, the chart underneath
          // must still be the one just selected, not reverted or blanked.
          _expectRenderedChartType(currentChartRightPanel($), type);
        },
      );
    }
  });

  group('Chart type switching — dual-panel right side', () {
    patrolTest(
      'selecting Volume Candle updates the chart\'s selected type, and the '
      'chart canvas is visible again once the menu is closed',
      ($) async {
        await openChartAndAwaitLoad($);
        await selectChartLayout($, 'indexCallPut');

        await openChartTypeMenuRightPanel($);
        await tapChartTypeRow($, ChartType.volumeCandle.name);
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        final radioGroup = $.tester
            .widgetList<RadioGroup<ChartType>>(
              find.byType(RadioGroup<ChartType>),
            )
            .first;
        expect(radioGroup.groupValue, ChartType.volumeCandle);

        // Close the menu -- the chart-type picker unmounts, and the actual
        // chart canvas underneath (rendering the volume-scaled candles)
        // must be the thing left on screen.
        await closeChartTypeMenuRightPanel($);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
        expect(find.byType(RadioGroup<ChartType>), findsNothing);
        // The chart is still alive and rendering underneath, not blanked
        // by whatever mounted/unmounted while the menu opened and closed.
        expect($(Key(ChartTestKeys.debugVisibleRange)), findsWidgets);
      },
    );

    patrolTest(
      'selecting OHLC updates the chart\'s selected type, and the chart '
      'canvas is visible again once the menu is closed',
      ($) async {
        await openChartAndAwaitLoad($);
        await selectChartLayout($, 'indexCallPut');

        await openChartTypeMenuRightPanel($);
        await tapChartTypeRow($, ChartType.ohlcBars.name);
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        final radioGroup = $.tester
            .widgetList<RadioGroup<ChartType>>(
              find.byType(RadioGroup<ChartType>),
            )
            .first;
        expect(radioGroup.groupValue, ChartType.ohlcBars);

        await closeChartTypeMenuRightPanel($);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
        expect(find.byType(RadioGroup<ChartType>), findsNothing);
        // The chart is still alive and rendering underneath, not blanked
        // by whatever mounted/unmounted while the menu opened and closed.
        expect($(Key(ChartTestKeys.debugVisibleRange)), findsWidgets);
      },
    );

    patrolTest(
      'switching back to Candle after Volume Candle updates the selected '
      'type again',
      ($) async {
        await openChartAndAwaitLoad($);
        await selectChartLayout($, 'indexCallPut');

        // Keep the menu open across both selections: the toggle button is
        // a toggle, so reopening it while already open would close it
        // instead.
        await openChartTypeMenuRightPanel($);
        await tapChartTypeRow($, ChartType.volumeCandle.name);
        await $.pumpAndSettle();

        await tapChartTypeRow($, ChartType.candle.name);
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        final radioGroup = $.tester
            .widgetList<RadioGroup<ChartType>>(
              find.byType(RadioGroup<ChartType>),
            )
            .first;
        expect(radioGroup.groupValue, ChartType.candle);
      },
    );

    patrolTest('cycling through all chart types from the right panel does not '
        'produce error state', ($) async {
      await openChartAndAwaitLoad($);
      await selectChartLayout($, 'indexCallPut');

      // Stay on the chart-types tab and tap each row in turn rather than
      // reopening the menu every time: the menu toggle button is a toggle,
      // so re-tapping it while still open would close it instead of
      // refreshing it.
      await openChartTypeMenuRightPanel($);
      for (final type in ChartType.values) {
        await tapChartTypeRow($, type.name);
        await $.pumpAndSettle();
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      }

      final radioGroup = $.tester
          .widgetList<RadioGroup<ChartType>>(find.byType(RadioGroup<ChartType>))
          .first;
      expect(radioGroup.groupValue, ChartType.values.last);
    });
  });
}
