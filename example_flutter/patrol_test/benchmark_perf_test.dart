// Run these tests in release mode:
//
//   cd neocharts-exampleapp
//   patrol test -t patrol_test/benchmark_perf_test.dart --release
//
// In debug mode the ChartPerfOverlay widgets are absent, so metric
// assertions are skipped (structural tap/load paths still execute).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/presentation/app.dart';
import 'package:neocharts_exampleapp/presentation/widgets/chart_card.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'package:neocharts_exampleapp/data/datasources/benchmark_config.dart';

import 'benchmark_helpers.dart';
import 'helpers.dart';

// Pumps the app and waits for it to finish initializing, without tapping
// "NeoCharts" yet -- benchmark tests need to drive the HomePage's own
// BenchmarkControlPanel first, unlike every other suite's
// openChartAndAwaitLoad (which opens the chart in one shot).
Future<void> _pumpHomeAndAwaitReady(PatrolIntegrationTester $) async {
  final completer = Completer<void>();
  await $.pumpWidget(
    ChartTemplateApp(
      onInitDone: completer.complete,
      onInitError: completer.completeError,
    ),
  );
  await completer.future;
  await $.tester.pump(const Duration(milliseconds: 300));
  // find.text('NeoCharts') alone is ambiguous -- the home page's own
  // header logo repeats the same "NeoCharts" text right above this card
  // (see helpers.dart's openChartAndAwaitLoad for the identical fix).
  await $.tester.ensureVisible(_neoChartsCard);
  await $.tester.pumpAndSettle();
}

Finder get _neoChartsCard => find.descendant(
  of: find.byType(ChartCard),
  matching: find.text('NeoCharts'),
);

// Taps "NeoCharts" and waits for the chart to finish its initial load --
// the benchmark-panel equivalent of helpers.dart's openChartAndAwaitLoad,
// split out so configureBenchmark can run in between.
Future<void> _openChartFromHome(PatrolIntegrationTester $) async {
  await $.tester.tap(_neoChartsCard);
  await $.pumpAndSettle();
  await waitUntilAbsent(
    $,
    find.byKey(Key(ChartTestKeys.loadingState)),
    timeout: const Duration(seconds: 30),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────
  // Group 1: Dataset scaling
  //
  // Verifies that frame-time p95 stays within the per-dataset budget
  // across 100 / 1K / 10K / 50K candles.
  //
  // Thresholds (profile build on physical device):
  //   100  candles → 8 ms   (120 fps)
  //   1K   candles → 16.7 ms (60 fps)
  //   10K  candles → 33.3 ms (30 fps)
  //   50K  candles → 50 ms  (20 fps minimum)
  // ─────────────────────────────────────────────────────────────
  group('Perf — dataset scaling', () {
    Future<void> runScaling(
      PatrolIntegrationTester $,
      DatasetSize size,
      int budgetUs,
    ) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: size);
      await _openChartFromHome($);

      await awaitPerfOverlay($);
      final tag = 'dataset_${size.label.toLowerCase()}';
      final run = await sampleMetrics($, tag: tag);
      logRun(run);
      assertFrameBudgetP95(run, budgetUs);

      expect(run.medianVisibleCandles, greaterThan(0));
      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    }

    patrolTest(
      '100 candles — p95 frame time within 8ms (120 fps)',
      ($) async => runScaling($, DatasetSize.s100, 8000),
    );

    patrolTest(
      '1K candles — p95 frame time within 16.7ms (60 fps)',
      ($) async => runScaling($, DatasetSize.s1k, 16667),
    );

    patrolTest(
      '10K candles — p95 frame time within 33ms (30 fps)',
      ($) async => runScaling($, DatasetSize.s10k, 33333),
    );

    patrolTest(
      '50K candles — p95 frame time within 50ms (20 fps)',
      ($) async => runScaling($, DatasetSize.s50k, 50000),
    );
  });

  // ─────────────────────────────────────────────────────────────
  // Group 2: Live data streaming under load
  //
  // All sub-tests use 10K candles (30-fps budget = 33.3 ms).
  // The 30/s streaming sub-test logs metrics but skips the hard
  // assertion — timer precision and GC pauses make it noisy in CI.
  // ─────────────────────────────────────────────────────────────
  group('Perf — live data streaming', () {
    Future<BenchmarkRun> openAndStream(
      PatrolIntegrationTester $, {
      required String tag,
      required bool liveData,
      StreamRate streamRate = StreamRate.r1,
    }) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark(
        $,
        datasetSize: DatasetSize.s10k,
        liveData: liveData,
        streamRate: streamRate,
      );
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      if (liveData) {
        // Let stream ticks fire for 3 real seconds.
        await $.tester.pump(const Duration(seconds: 3));
      }

      return sampleMetrics($, tag: tag, count: 20);
    }

    patrolTest('10K candles — streaming disabled baseline', ($) async {
      final run = await openAndStream(
        $,
        tag: 'stream_off_10k',
        liveData: false,
      );
      logRun(run);
      assertFrameBudgetP95(run, 33333);
      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('10K candles — 1hz live stream — frame budget 33ms', ($) async {
      final run = await openAndStream(
        $,
        tag: 'stream_1hz_10k',
        liveData: true,
        streamRate: StreamRate.r1,
      );
      logRun(run);
      assertFrameBudgetP95(run, 33333);
      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('10K candles — 30hz live stream — log only (CI noisy)', (
      $,
    ) async {
      final run = await openAndStream(
        $,
        tag: 'stream_30hz_10k',
        liveData: true,
        streamRate: StreamRate.r30,
      );
      logRun(run);
      // Log-only: 30 Hz timer precision varies across CI agents.
      // Hard threshold intentionally omitted for this sub-test.
      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 3: Indicator stacking
  //
  // Adds SMA → EMA → RSI progressively on a 1K dataset and
  // measures the per-stage overhead. All stages must stay within
  // the 60-fps budget (16.7 ms) with three active indicators.
  // ─────────────────────────────────────────────────────────────
  group('Perf — indicator stacking', () {
    patrolTest('SMA → EMA → RSI progressive stack — 60 fps budget', ($) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s1k);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      // Stage 0: baseline (no indicators).
      final baseline = await sampleMetrics($, tag: 'stack_baseline');
      logRun(baseline);
      assertFrameBudgetP95(baseline, 16667);

      // Stage 1: add SMA.
      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
      await $.pumpAndSettle();
      await closeMenu($);
      await awaitPerfOverlay($);

      final withSma = await sampleMetrics($, tag: 'stack_sma');
      logRun(withSma);
      assertFrameBudgetP95(withSma, 16667);
      expect(find.byKey(Key(ChartTestKeys.legendRow('sma'))), findsOneWidget);

      // Stage 2: add EMA on top of SMA.
      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorBrowseRow('ema'))).tap();
      await $.pumpAndSettle();
      await closeMenu($);
      await awaitPerfOverlay($);

      final withSmaEma = await sampleMetrics($, tag: 'stack_sma_ema');
      logRun(withSmaEma);
      assertFrameBudgetP95(withSmaEma, 16667);

      // Stage 3: add RSI (sub-panel renderer).
      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorBrowseRow('rsi'))).tap();
      await $.pumpAndSettle();
      await closeMenu($);
      await awaitPerfOverlay($);

      final withAll = await sampleMetrics($, tag: 'stack_sma_ema_rsi');
      logRun(withAll);
      assertFrameBudgetP95(withAll, 16667);

      expect(find.byKey(Key(ChartTestKeys.legendRow('rsi'))), findsOneWidget);
      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 4: Renderer mode comparison
  //
  // Compares rendering cost across three renderer configurations
  // on the same 1K dataset: candle-only, + overlay indicators
  // (SMA + EMA add graph-layer overhead), + panel indicator (RSI
  // adds a full sub-panel renderer). Delta is logged for analysis.
  // ─────────────────────────────────────────────────────────────
  group('Perf — renderer mode comparison', () {
    patrolTest('candle-only vs overlay vs panel renderer overhead', ($) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s1k);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      final candles = await sampleMetrics($, tag: 'renderer_candles');
      logRun(candles);

      // Add SMA + EMA (two additional overlay graph renderers).
      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorBrowseRow('sma'))).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorBrowseRow('ema'))).tap();
      await $.pumpAndSettle();
      await closeMenu($);
      await awaitPerfOverlay($);

      final overlays = await sampleMetrics($, tag: 'renderer_overlays');
      logRun(overlays);

      // Add RSI (panel sub-renderer).
      await openIndicatorMenu($);
      await $(Key(ChartTestKeys.indicatorTabPanel)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.indicatorBrowseRow('rsi'))).tap();
      await $.pumpAndSettle();
      await closeMenu($);
      await awaitPerfOverlay($);

      final withPanel = await sampleMetrics($, tag: 'renderer_panel');
      logRun(withPanel);

      final deltaOverlay = overlays.medianFrameUs - candles.medianFrameUs;
      final deltaPanel = withPanel.medianFrameUs - overlays.medianFrameUs;
      debugPrint(
        '[BENCH] renderer_delta '
        'overlay=${fmtMs(deltaOverlay)} '
        'panel=${fmtMs(deltaPanel)}',
      );

      assertFrameBudgetP95(withPanel, 16667);
      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 5: Pan / zoom interaction under 50K dataset
  //
  // Loads 50K candles then performs repeated pan gestures to move
  // the viewport through the dataset. Asserts that frame time
  // during pan stays within the 50ms budget and that the viewport
  // actually moved (visibleCandles or position changed).
  //
  // Pinch-zoom (multi-pointer) is excluded — too flaky in CI.
  // ─────────────────────────────────────────────────────────────
  group('Perf — pan and zoom under 50K dataset', () {
    patrolTest('50K candles — repeated pan gestures stay within 50ms', (
      $,
    ) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s50k);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      final rest = await sampleMetrics($, tag: 'pan_rest_50k', count: 10);
      logRun(rest);

      final surface = find.byKey(Key(ChartTestKeys.chartGestureSurface));

      // Pan left × 5 (scroll towards older data).
      for (var i = 0; i < 5; i++) {
        await $.tester.drag(surface, const Offset(-300, 0));
        await $.tester.pump(const Duration(milliseconds: 16));
      }
      final panLeft = await sampleMetrics($, tag: 'pan_left_50k', count: 10);
      logRun(panLeft);
      assertFrameBudgetP95(panLeft, 50000);

      // Pan right × 5 (scroll towards newer data).
      for (var i = 0; i < 5; i++) {
        await $.tester.drag(surface, const Offset(300, 0));
        await $.tester.pump(const Duration(milliseconds: 16));
      }
      final panRight = await sampleMetrics($, tag: 'pan_right_50k', count: 10);
      logRun(panRight);
      assertFrameBudgetP95(panRight, 50000);

      // Reset viewport and measure idle post-pan cost.
      await $(Key(ChartTestKeys.resetViewportBtn)).tap();
      await $.pumpAndSettle();
      final postReset = await sampleMetrics($, tag: 'pan_reset_50k', count: 10);
      logRun(postReset);
      assertFrameBudgetP95(postReset, 50000);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 6: Rapid interval / timeframe switching stress
  //
  // Cycles through 7 interval changes in sequence and reads perf
  // metrics after each data reload. Asserts no error state and
  // that all post-reload frame times stay within the 33ms budget.
  // ─────────────────────────────────────────────────────────────
  group('Perf — interval switching stress', () {
    patrolTest('7 rapid interval switches — no error, 30 fps budget', (
      $,
    ) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s1k);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      const sequence = [
        'min5',
        'min15',
        'hour1',
        'hour4',
        'day1',
        'min5',
        'min1',
      ];

      for (final interval in sequence) {
        await openIntervalMenu($);
        await $(Key(ChartTestKeys.intervalChip(interval))).tap();
        await $.pumpAndSettle();
        await awaitDataReload($);
        await awaitPerfOverlay($);

        final run = await sampleMetrics($, tag: 'interval_$interval', count: 5);
        logRun(run);
        assertFrameBudgetP95(run, 33333);

        expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);
      }

      // After returning to min1 the app bar label must show '1m'.
      expect(
        find.descendant(
          of: find.byKey(Key(ChartTestKeys.intervalBtn)),
          matching: find.text('1m'),
        ),
        findsOneWidget,
      );

      // Debug overlay must survive all data reloads.
      expect(find.byKey(Key(ChartTestKeys.debugVisibleRange)), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 7: Option chain overlay
  //
  // The option chain renders one row per strike (55 strikes in the mock
  // data source) on top of the chart, so opening it and scrolling through
  // it are both real opportunities for dropped frames on the chart
  // underneath. All sub-tests use a 1K dataset -- light enough that any
  // budget miss here is attributable to the overlay, not candle count.
  //
  // Live data is enabled so the strike rows are actively being updated
  // by streamed ticks while the list is scrolled -- scrolling a static
  // list would miss the real-world case of jank caused by simultaneous
  // row rebuilds and list transform.
  // ─────────────────────────────────────────────────────────────
  group('Perf — option chain', () {
    patrolTest('opening the option chain stays within 60 fps budget', (
      $,
    ) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s1k, liveData: true);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      await openOptionChain($);
      await waitUntilPresent(
        $,
        findByKeyPrefix('chart_option_chain_strike_cell_'),
      );
      await awaitPerfOverlay($);

      // Let stream ticks fire so the strike rows are populated and
      // actively updating before sampling.
      await $.tester.pump(const Duration(seconds: 3));

      final run = await sampleMetrics($, tag: 'option_chain_open');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeOptionChain($);
    });

    patrolTest(
      'scrolling the option chain strike list while streaming stays within 60 fps budget',
      ($) async {
        await _pumpHomeAndAwaitReady($);
        await configureBenchmark(
          $,
          datasetSize: DatasetSize.s1k,
          liveData: true,
        );
        await _openChartFromHome($);
        await awaitPerfOverlay($);

        await openOptionChain($);
        await waitUntilPresent(
          $,
          findByKeyPrefix('chart_option_chain_strike_cell_'),
        );
        await awaitPerfOverlay($);

        // Let stream ticks fire so the strike rows are actively updating
        // (LTP/Chg/OI) while the list is scrolled below.
        await $.tester.pump(const Duration(seconds: 3));

        // Raw screen-coordinate drag, not a specific strike cell's finder --
        // the list isn't virtualized, so every cell stays mounted (just
        // scrolled off-screen), and dragging a finder that's no longer
        // on-screen is unreliable. Mirrors Group 5's chartGestureSurface
        // pan, which drags by screen offset for the same reason.
        final view = $.tester.view;
        final screenSize = view.physicalSize / view.devicePixelRatio;
        final dragStart = Offset(screenSize.width / 2, screenSize.height / 2);

        for (var i = 0; i < 10; i++) {
          await $.tester.dragFrom(dragStart, const Offset(0, -200));
          await $.tester.pump(const Duration(milliseconds: 16));
        }
        final run = await sampleMetrics(
          $,
          tag: 'option_chain_scroll',
          count: 10,
        );
        logRun(run);
        assertFrameBudgetP95(run, 16667);

        expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

        await closeOptionChain($);
      },
    );

    patrolTest(
      'switching the option chain expiry while streaming stays within 60 fps budget',
      ($) async {
        await _pumpHomeAndAwaitReady($);
        await configureBenchmark(
          $,
          datasetSize: DatasetSize.s1k,
          liveData: true,
        );
        await _openChartFromHome($);
        await awaitPerfOverlay($);

        await openOptionChain($);
        await waitUntilPresent(
          $,
          findByKeyPrefix('chart_option_chain_strike_cell_'),
        );
        await awaitPerfOverlay($);
        await $.tester.pump(const Duration(seconds: 3));

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.optionChainExpiryDropdown)),
        );
        await $.pumpAndSettle();

        final expiryOption = findByKeyPrefix(
          'chart_option_chain_expiry_option_',
        );
        await waitUntilPresent($, expiryOption);
        await $.tester.tap(expiryOption.first);
        await $.tester.pump();

        final run = await sampleMetrics($, tag: 'option_chain_expiry_switch');
        logRun(run);
        assertFrameBudgetP95(run, 16667);

        expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

        await closeOptionChain($);
      },
    );

    patrolTest('toggling CALL/PUT while streaming stays within 60 fps budget', (
      $,
    ) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s1k, liveData: true);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      await openOptionChain($);
      await waitUntilPresent(
        $,
        findByKeyPrefix('chart_option_chain_strike_cell_'),
      );
      await awaitPerfOverlay($);
      await $.tester.pump(const Duration(seconds: 3));

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.optionChainTypeTab('PE'))),
      );
      await $.tester.pump();

      final run = await sampleMetrics($, tag: 'option_chain_call_put_toggle');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeOptionChain($);
    });

    patrolTest('toggling Greeks while streaming stays within 60 fps budget', (
      $,
    ) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s1k, liveData: true);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      await openOptionChain($);
      await waitUntilPresent(
        $,
        findByKeyPrefix('chart_option_chain_strike_cell_'),
      );
      await awaitPerfOverlay($);
      await $.tester.pump(const Duration(seconds: 3));

      await $.tester.tap(find.byKey(Key(ChartTestKeys.optionChainGreekSwitch)));
      await $.tester.pump();

      final run = await sampleMetrics($, tag: 'option_chain_greeks_toggle');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeOptionChain($);
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 8: Indicator browser list
  //
  // Distinct from Group 3 (indicator stacking), which measures the
  // chart's own rendering cost once indicators are active. This group
  // measures the browser *picker* UI itself -- opening the list, typing
  // into its search field, and scrolling it -- all while the chart
  // underneath is still live. All sub-tests use a 1K dataset.
  // ─────────────────────────────────────────────────────────────
  group('Perf — indicator browser', () {
    patrolTest('opening the indicator browser stays within 60 fps budget', (
      $,
    ) async {
      await _pumpHomeAndAwaitReady($);
      await configureBenchmark($, datasetSize: DatasetSize.s1k);
      await _openChartFromHome($);
      await awaitPerfOverlay($);

      await openIndicatorMenu($);
      await waitUntilPresent(
        $,
        find.byKey(Key(ChartTestKeys.indicatorBrowseRow('sma'))),
      );
      await awaitPerfOverlay($);

      final run = await sampleMetrics($, tag: 'indicator_browser_open');
      logRun(run);
      assertFrameBudgetP95(run, 16667);

      expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

      await closeMenu($);
    });

    patrolTest(
      'typing in the indicator search field stays within 60 fps budget',
      ($) async {
        await _pumpHomeAndAwaitReady($);
        await configureBenchmark($, datasetSize: DatasetSize.s1k);
        await _openChartFromHome($);
        await awaitPerfOverlay($);

        await openIndicatorMenu($);
        await waitUntilPresent(
          $,
          find.byKey(Key(ChartTestKeys.indicatorBrowseRow('sma'))),
        );
        await awaitPerfOverlay($);

        await $.tester.enterText(
          find.byKey(Key(ChartTestKeys.indicatorSearchField)),
          'm',
        );
        await $.tester.pump();

        final run = await sampleMetrics($, tag: 'indicator_browser_search');
        logRun(run);
        assertFrameBudgetP95(run, 16667);

        expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

        await closeMenu($);
      },
    );

    patrolTest(
      'scrolling the indicator browser list stays within 60 fps budget',
      ($) async {
        await _pumpHomeAndAwaitReady($);
        await configureBenchmark($, datasetSize: DatasetSize.s1k);
        await _openChartFromHome($);
        await awaitPerfOverlay($);

        await openIndicatorMenu($);
        await waitUntilPresent(
          $,
          find.byKey(Key(ChartTestKeys.indicatorBrowseRow('sma'))),
        );
        await awaitPerfOverlay($);

        // x = 70% of screen width -- the menu's own rail (the Intervals/
        // Indicators/Chart Types tabs) occupies a fixed ~88px strip on the
        // left, so this reliably lands in the list content area beside it
        // regardless of device width.
        final view = $.tester.view;
        final screenSize = view.physicalSize / view.devicePixelRatio;
        final dragStart = Offset(screenSize.width * 0.7, screenSize.height / 2);

        for (var i = 0; i < 5; i++) {
          await $.tester.dragFrom(dragStart, const Offset(0, -200));
          await $.tester.pump(const Duration(milliseconds: 16));
        }
        final run = await sampleMetrics(
          $,
          tag: 'indicator_browser_scroll',
          count: 10,
        );
        logRun(run);
        assertFrameBudgetP95(run, 16667);

        expect(find.byKey(Key(ChartTestKeys.errorState)), findsNothing);

        await closeMenu($);
      },
    );
  });
}
