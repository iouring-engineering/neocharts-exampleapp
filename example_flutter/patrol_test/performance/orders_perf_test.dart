import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/data/repositories/nxt_chart_repository.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../benchmark_helpers.dart';
import '../helpers.dart';
import 'performance_test_helpers.dart';

// Perf — orders list
//
// Seeds a large number of open orders via NxtChartRepository.seedOrders (a
// test-only bulk hook -- placeOrder routes every call through the
// fill/position pipeline, which isn't needed here) and measures opening
// and scrolling the orders panel under that load. Individual order rows
// carry no dedicated item key (only their modify/cancel buttons do -- see
// findAnyOrderModifyBtn in helpers.dart), so that prefix finder doubles as
// the "list is populated" signal here.
const _orderCount = 150;

void main() {
  group('Perf — orders list', () {
    patrolTest('opening the orders panel stays within 60 fps budget', (
      $,
    ) async {
      final mock = NxtChartRepository(storageKey: 'perf_orders_open');
      await openChartAndAwaitLoad($, interfaceOverride: mock);
      mock.seedOrders(_orderCount);
      await awaitPerfOverlay($);

      await openOrdersPanel($);
      await waitUntilPresent($, findAnyOrderModifyBtn());
      await awaitPerfOverlay($);

      final run = await sampleMetrics($, tag: 'orders_open');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('scrolling the orders list stays within 60 fps budget', (
      $,
    ) async {
      final mock = NxtChartRepository(storageKey: 'perf_orders_scroll');
      await openChartAndAwaitLoad($, interfaceOverride: mock);
      mock.seedOrders(_orderCount);
      await awaitPerfOverlay($);

      await openOrdersPanel($);
      await waitUntilPresent($, findAnyOrderModifyBtn());
      await awaitPerfOverlay($);

      await dragListUp($, times: 10);

      final run = await sampleMetrics($, tag: 'orders_scroll', count: 10);
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });
}
