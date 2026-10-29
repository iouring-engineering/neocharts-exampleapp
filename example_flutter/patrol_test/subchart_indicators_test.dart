import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/enums/chart_indicator.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// Sub-chart (panel) indicators that exist in the SDK. Add a row here when a
// new panel indicator is implemented.
const _subchartIndicators = <ChartIndicator>[
  ChartIndicator.cmf,
  ChartIndicator.hv,
  ChartIndicator.momentum,
  ChartIndicator.netVolume,
  ChartIndicator.obv,
];

void main() {
  group('Sub-chart indicators', () {
    for (final indicator in _subchartIndicators) {
      patrolTest('add and remove ${indicator.fullName}', ($) async {
        await openChartAndAwaitLoad($);

        await openIndicatorMenu($);
        await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
        await $.pumpAndSettle();
        // The panel list is a lazy ListView.builder: rows below the fold
        // aren't built until scrolled to, so scroll until the row exists.
        final row = $(Key(ChartTestKeys.indicatorBrowseRow(indicator.key)));
        // Scroll in small, slow steps so no lazily-built row is skipped.
        final list = find.byType(ListView).last;
        for (var i = 0; i < 150; i++) {
          if (row.finder.evaluate().isNotEmpty) {
            await $.tester.ensureVisible(row.finder);
            await $.pump(const Duration(milliseconds: 300));
            break;
          }
          await $.tester.drag(list, const Offset(0, -60));
          await $.pump(const Duration(milliseconds: 300));
        }
        await $.pumpAndSettle();
        await row.tap();
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.legendRow(indicator.key))), findsOneWidget);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        // The menu still covers the legend, so remove via the Active view:
        // tapping an active row removes the indicator.
        await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
        await $.pumpAndSettle();
        final active = $(Key(ChartTestKeys.indicatorActiveRow(indicator.key)));
        expect(active, findsOneWidget);
        await active.tap();
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.legendRow(indicator.key))), findsNothing);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      });
    }
  });
}
