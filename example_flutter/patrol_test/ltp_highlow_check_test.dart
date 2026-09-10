// Manual verification test (not part of the permanent suite): confirms the
// LTP crossline marker moves for every ChartType while ticks stream, via the
// normal (single-panel) chart and its own chart-type menu -- reachable
// through the app bar's settings icon.
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:financial_chart/financial_chart.dart';
import 'package:nxtchart/src/enums/chart_type.dart';
import 'package:nxtchart/src/shared/constants.dart';

import 'helpers.dart';

void main() {
  patrolTest('LTP marker moves while ticks stream, for every chart type', (
    $,
  ) async {
    await openChartAndAwaitLoad($);

    for (final type in ChartType.values) {
      await openChartTypeMenu($);
      await tapChartTypeRow($, type.name);
      await $.pumpAndSettle();
      // NxtPopup paints a full-screen barrier above the toggle button while
      // open, so the toggle itself isn't hit-testable to close it -- tap
      // outside the popup panel instead (mirrors
      // closeChartTypeMenuRightPanel in helpers.dart).
      await tapOutsideModal($);

      // Single-panel layout, so the one `debugVisibleRange` widget is both
      // the first and the last match -- safe to reuse the dual-panel
      // lookup here.
      final chart = currentChartRightPanel($);
      final panel = chart.findPanelByID(Constants.mainPanel)!;
      final liveMarker = panel
          .findGraphById(type.mainGraphId)!
          .findMarker(Constants.liveMarker)!;

      final before = (liveMarker.keyCoordinates.first as GCustomCoord).y;

      // Let several ticks stream in.
      for (var i = 0; i < 6; i++) {
        await $.tester.pump(const Duration(seconds: 1));
      }
      await $.pumpAndSettle();

      final after = (liveMarker.keyCoordinates.first as GCustomCoord).y;

      // ignore: avoid_print
      print(
        'LTP marker ${type.name}: before=$before after=$after '
        'moved=${before != after}',
      );
      expect(
        after,
        isNot(equals(before)),
        reason: 'LTP marker did not move for chart type ${type.name}',
      );
    }
  });
}
