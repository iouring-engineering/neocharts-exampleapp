import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:neocharts_exampleapp/data/datasources/benchmark_config.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

/// Single-frame timing snapshot read from the perf overlay widgets.
class BenchmarkSample {
  const BenchmarkSample({
    required this.frameTimeUs,
    required this.renderTimeUs,
    required this.paintTimeUs,
    required this.visibleCandles,
  });

  final int frameTimeUs;
  final int renderTimeUs;
  final int paintTimeUs;
  final int visibleCandles;
}

/// Aggregates multiple [BenchmarkSample]s for one scenario stage.
class BenchmarkRun {
  BenchmarkRun({required this.tag, required this.samples});

  final String tag;
  final List<BenchmarkSample> samples;

  int get medianFrameUs => _median(samples.map((s) => s.frameTimeUs).toList());

  int get p95FrameUs => _p95(samples.map((s) => s.frameTimeUs).toList());

  int get medianRenderUs =>
      _median(samples.map((s) => s.renderTimeUs).toList());

  int get medianPaintUs => _median(samples.map((s) => s.paintTimeUs).toList());

  int get medianVisibleCandles =>
      _median(samples.map((s) => s.visibleCandles).toList());
}

int _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) ~/ 2;
}

int _p95(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.from(values)..sort();
  final idx = ((sorted.length - 1) * 0.95).round();
  return sorted[idx];
}

int _parseMicros(String? text) {
  if (text == null) return 0;
  return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

BenchmarkSample _readOneSample(WidgetTester tester) {
  String? textOf(String key) {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) return null;
    return (tester.widget(f) as Text).data;
  }

  final candleStr = textOf(ChartTestKeys.perfVisibleCandles);
  return BenchmarkSample(
    frameTimeUs: _parseMicros(textOf(ChartTestKeys.perfFrameTime)),
    renderTimeUs: _parseMicros(textOf(ChartTestKeys.perfRenderTime)),
    paintTimeUs: _parseMicros(textOf(ChartTestKeys.perfPaintTime)),
    visibleCandles: int.tryParse(candleStr?.trim() ?? '0') ?? 0,
  );
}

/// Polls until the perf overlay has emitted at least one frame of
/// metrics (i.e. [ChartTestKeys.perfFrameTime] is in the tree).
///
/// Fails if [timeout] elapses — most likely the test was not launched
/// in profile mode (--profile).
Future<void> awaitPerfOverlay(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 8),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  final finder = find.byKey(Key(ChartTestKeys.perfFrameTime));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'ChartPerfOverlay metrics not found within '
        '${timeout.inSeconds}s — run tests with --profile.',
      );
    }
    await $.tester.pump(interval);
  }
}

/// Pumps [count] frames (after [warmupFrames] warm-up frames) at
/// [frameInterval] cadence, collecting one [BenchmarkSample] per
/// frame. Returns a [BenchmarkRun] ready for logging / assertion.
Future<BenchmarkRun> sampleMetrics(
  PatrolIntegrationTester $, {
  required String tag,
  int count = 15,
  int warmupFrames = 3,
  Duration frameInterval = const Duration(milliseconds: 16),
}) async {
  final samples = <BenchmarkSample>[];
  final total = count + warmupFrames;
  for (var i = 0; i < total; i++) {
    await $.tester.pump(frameInterval);
    if (i >= warmupFrames) {
      samples.add(_readOneSample($.tester));
    }
  }
  return BenchmarkRun(tag: tag, samples: samples);
}

String fmtMs(int us) => '${(us / 1000.0).toStringAsFixed(2)}ms';

/// Prints per-sample raw values plus a summary line to the test log.
void logRun(BenchmarkRun run) {
  for (var i = 0; i < run.samples.length; i++) {
    final s = run.samples[i];
    debugPrint(
      '[BENCH:${run.tag}:$i] '
      'frame=${fmtMs(s.frameTimeUs)} '
      'render=${fmtMs(s.renderTimeUs)} '
      'paint=${fmtMs(s.paintTimeUs)} '
      'candles=${s.visibleCandles}',
    );
  }
  debugPrint(
    '[BENCH] tag=${run.tag} '
    'median_frame=${fmtMs(run.medianFrameUs)} '
    'p95_frame=${fmtMs(run.p95FrameUs)} '
    'render=${fmtMs(run.medianRenderUs)} '
    'paint=${fmtMs(run.medianPaintUs)} '
    'candles=${run.medianVisibleCandles}',
  );
}

/// Asserts that the p95 frame time is within [budgetUs] microseconds.
/// No-op in debug builds — allows structural test runs without a
/// profile build.
void assertFrameBudgetP95(BenchmarkRun run, int budgetUs) {
  if (!kProfileMode) return;
  final p95 = run.p95FrameUs;
  if (p95 <= budgetUs) return;
  fail(
    '[BENCH] ${run.tag}: p95 frame time ${fmtMs(p95)} '
    'exceeds ${fmtMs(budgetUs)} budget.',
  );
}

/// Taps the [BenchmarkControlPanel] controls on the HomePage to establish
/// a deterministic [BenchmarkConfig] before opening the chart. Must be
/// called before tapping "NeoCharts" (e.g. before [openChartAndAwaitLoad]).
Future<void> configureBenchmark(
  PatrolIntegrationTester $, {
  required DatasetSize datasetSize,
  bool liveData = false,
  StreamRate streamRate = StreamRate.r1,
}) async {
  await $(Key(_datasetKey(datasetSize))).tap();
  await $.pumpAndSettle();

  final sw = $.tester.widget<Switch>(
    find.byKey(Key(BenchmarkTestKeys.liveDataToggle)),
  );
  if (sw.value != liveData) {
    await $(Key(BenchmarkTestKeys.liveDataToggle)).tap();
    await $.pumpAndSettle();
  }

  if (liveData) {
    await $(Key(_streamRateKey(streamRate))).tap();
    await $.pumpAndSettle();
  }
}

String _datasetKey(DatasetSize size) => switch (size) {
  DatasetSize.s100 => BenchmarkTestKeys.dataset100,
  DatasetSize.s1k => BenchmarkTestKeys.dataset1k,
  DatasetSize.s10k => BenchmarkTestKeys.dataset10k,
  DatasetSize.s50k => BenchmarkTestKeys.dataset50k,
};

String _streamRateKey(StreamRate rate) => switch (rate) {
  StreamRate.r1 => BenchmarkTestKeys.streamRate1,
  StreamRate.r10 => BenchmarkTestKeys.streamRate10,
  StreamRate.r30 => BenchmarkTestKeys.streamRate30,
};
