import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../benchmark_helpers.dart';
import '../helpers.dart';
import 'performance_test_helpers.dart';

// Perf — symbol search
//
// The mock symbol universe (MockChartDataSource.allSymbols) is 313 wide --
// 1 NIFTY index + 110 option-chain symbols (55 strikes x CE/PE) + 1 future
// + 1 INDIA VIX index + 200 synthetic equities added solely to give this
// suite a large, realistic universe to filter/scroll through (see
// MockChartDataSource.generateEquitySymbols). An empty query returns the
// whole list, so opening the panel with no query already exercises the
// large-dataset case without any seeding step.
void main() {
  group('Perf — symbol search', () {
    patrolTest('opening the symbol search panel stays within 60 fps budget', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await awaitPerfOverlay($);

      await openSymbolSearch($);
      await waitUntilPresent($, findByKeyPrefix('chart_symbol_search_result_'));
      await awaitPerfOverlay($);

      final run = await sampleMetrics($, tag: 'symbol_search_open');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeSymbolSearch($);
    });

    patrolTest('typing in the symbol search field stays within 60 fps budget', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await awaitPerfOverlay($);

      await openSymbolSearch($);
      await waitUntilPresent($, findByKeyPrefix('chart_symbol_search_result_'));
      await awaitPerfOverlay($);

      await $.tester.enterText(
        fieldByKey(ChartTestKeys.symbolSearchField),
        'e',
      );
      await $.tester.pump();

      final run = await sampleMetrics($, tag: 'symbol_search_type');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeSymbolSearch($);
    });

    patrolTest(
      'scrolling the symbol search results stays within 60 fps budget',
      ($) async {
        await openChartAndAwaitLoad($);
        await awaitPerfOverlay($);

        await openSymbolSearch($);
        await waitUntilPresent(
          $,
          findByKeyPrefix('chart_symbol_search_result_'),
        );
        await awaitPerfOverlay($);

        await dragListUp($, times: 10);

        final run = await sampleMetrics(
          $,
          tag: 'symbol_search_scroll',
          count: 10,
        );
        logRun(run);
        assertFrameBudgetP95(run, 16667);

        expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

        await closeSymbolSearch($);
      },
    );

    patrolTest(
      'selecting a search result and switching symbol stays within 60 fps budget',
      ($) async {
        await openChartAndAwaitLoad($);
        await awaitPerfOverlay($);

        await openSymbolSearch($);
        final results = findByKeyPrefix('chart_symbol_search_result_');
        await waitUntilPresent($, results);
        await awaitPerfOverlay($);

        // Picks a synthetic equity ("EQ...") rather than the first result --
        // the first few results are the NIFTY index/options, which carry
        // their own option-chain/order-pad setup cost on top of a plain
        // symbol switch. An equity symbol isolates the cost of the switch
        // itself (chart + orders + positions + analysis re-init).
        final equityResult = find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'chart_symbol_search_result_EQ',
              ),
        );
        await waitUntilPresent($, equityResult);
        await $.tester.tap(equityResult.first);
        await $.tester.pump();
        await awaitDataReload($);

        final run = await sampleMetrics($, tag: 'symbol_search_select');
        logRun(run);
        assertFrameBudgetP95(run, 16667);

        expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
      },
    );
  });
}
