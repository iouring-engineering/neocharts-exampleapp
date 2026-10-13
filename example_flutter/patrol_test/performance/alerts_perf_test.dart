import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/data/repositories/nxt_chart_repository.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../benchmark_helpers.dart';
import '../helpers.dart';
import 'performance_test_helpers.dart';

// Perf — alerts list
//
// Seeds a large number of alerts via NxtChartRepository.seedAlerts (a
// test-only bulk hook -- the real create-alert dialog has no batch path)
// and measures opening and scrolling the alerts panel under that load.
// 150 alerts is comfortably beyond anything a real user would set up by
// hand, so this stresses the list the same way the option chain's 55-row
// strike list stresses that overlay in benchmark_perf_test.dart.
const _alertCount = 150;

void main() {
  group('Perf — alerts list', () {
    patrolTest('opening the alerts panel stays within 60 fps budget', (
      $,
    ) async {
      final mock = NxtChartRepository(storageKey: 'perf_alerts_open');
      await openChartAndAwaitLoad($, interfaceOverride: mock);
      mock.seedAlerts(_alertCount);
      await awaitPerfOverlay($);

      await openAlertsPanel($);
      await waitUntilPresent($, findByKeyPrefix('chart_alert_list_item_'));
      await awaitPerfOverlay($);

      final run = await sampleMetrics($, tag: 'alerts_open');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeAlertsPanel($);
    });

    patrolTest('scrolling the alerts list stays within 60 fps budget', (
      $,
    ) async {
      final mock = NxtChartRepository(storageKey: 'perf_alerts_scroll');
      await openChartAndAwaitLoad($, interfaceOverride: mock);
      mock.seedAlerts(_alertCount);
      await awaitPerfOverlay($);

      await openAlertsPanel($);
      await waitUntilPresent($, findByKeyPrefix('chart_alert_list_item_'));
      await awaitPerfOverlay($);

      await dragListUp($, times: 10);

      final run = await sampleMetrics($, tag: 'alerts_scroll', count: 10);
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeAlertsPanel($);
    });
  });
}
