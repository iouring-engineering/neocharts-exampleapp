import 'package:flutter/foundation.dart';
import 'package:neocharts_exampleapp/data/datasources/stream_rate.dart';

export 'package:neocharts_exampleapp/data/datasources/stream_rate.dart';

/// How many candles a benchmark run asks the mock data source to
/// generate, overriding whatever the chart itself would normally request
/// for its initial viewport.
enum DatasetSize { s100, s1k, s10k, s50k }

extension DatasetSizeX on DatasetSize {
  int get candleCount => const {
    DatasetSize.s100: 100,
    DatasetSize.s1k: 1000,
    DatasetSize.s10k: 10000,
    DatasetSize.s50k: 50000,
  }[this]!;

  String get label => const {
    DatasetSize.s100: '100',
    DatasetSize.s1k: '1K',
    DatasetSize.s10k: '10K',
    DatasetSize.s50k: '50K',
  }[this]!;
}

@immutable
class BenchmarkConfig {
  const BenchmarkConfig({
    this.datasetSize = DatasetSize.s1k,
    this.liveDataEnabled = true,
    this.streamRate = StreamRate.r1,
  });

  final DatasetSize datasetSize;
  final bool liveDataEnabled;
  final StreamRate streamRate;

  BenchmarkConfig copyWith({
    DatasetSize? datasetSize,
    bool? liveDataEnabled,
    StreamRate? streamRate,
  }) => BenchmarkConfig(
    datasetSize: datasetSize ?? this.datasetSize,
    liveDataEnabled: liveDataEnabled ?? this.liveDataEnabled,
    streamRate: streamRate ?? this.streamRate,
  );
}

abstract final class BenchmarkTestKeys {
  static const String panel = 'bench_panel';
  static const String dataset100 = 'bench_dataset_100';
  static const String dataset1k = 'bench_dataset_1k';
  static const String dataset10k = 'bench_dataset_10k';
  static const String dataset50k = 'bench_dataset_50k';
  static const String liveDataToggle = 'bench_live_data_toggle';
  static const String streamRate1 = 'bench_stream_rate_1';
  static const String streamRate10 = 'bench_stream_rate_10';
  static const String streamRate30 = 'bench_stream_rate_30';
}
