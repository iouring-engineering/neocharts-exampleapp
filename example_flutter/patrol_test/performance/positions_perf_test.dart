import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../benchmark_helpers.dart';
import '../helpers.dart';
import 'performance_test_helpers.dart';

// Perf — positions list
//
// Seeds a large number of distinct option positions via
// NeoChartsRepository.seedPositions (a test-only bulk hook -- each row uses
// a different option-chain symbol, unlike looping seedPosition, which is
// always NIFTY and would collide on the same list-item key) and measures
// opening and scrolling the positions panel under that load. 100 is
// comfortably beyond a real trader's open-position count and stays safely
// under the option chain's own 110-symbol universe (55 strikes x CE/PE),
// so every seeded row gets a distinct symID.
const _positionCount = 100;

void main() {
  group('Perf — positions list', () {
    patrolTest('opening the positions panel stays within 60 fps budget', (
      $,
    ) async {
      final mock = NeoChartsRepository(storageKey: 'perf_positions_open');
      await openChartAndAwaitLoad($, hostOverride: mock);
      mock.seedPositions(_positionCount);
      await awaitPerfOverlay($);

      await openPositionsPanel($);
      await waitUntilPresent($, findByKeyPrefix('chart_position_list_item_'));
      await awaitPerfOverlay($);

      final run = await sampleMetrics($, tag: 'positions_open');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closePositionsPanel($);
    });

    patrolTest('scrolling the positions list stays within 60 fps budget', (
      $,
    ) async {
      final mock = NeoChartsRepository(storageKey: 'perf_positions_scroll');
      await openChartAndAwaitLoad($, hostOverride: mock);
      mock.seedPositions(_positionCount);
      await awaitPerfOverlay($);

      await openPositionsPanel($);
      await waitUntilPresent($, findByKeyPrefix('chart_position_list_item_'));
      await awaitPerfOverlay($);

      await dragListUp($, times: 10);

      final run = await sampleMetrics($, tag: 'positions_scroll', count: 10);
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closePositionsPanel($);
    });
  });
}
