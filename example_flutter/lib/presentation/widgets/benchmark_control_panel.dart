import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/data/datasources/benchmark_config.dart';

/// Lets a Patrol benchmark test (or a curious developer) pick the dataset
/// size, live-data toggle, and stream rate the chart opens with next --
/// [onChanged] fires on every tap, and the caller is expected to apply the
/// resulting [BenchmarkConfig] the next time it opens the chart.
class BenchmarkControlPanel extends StatelessWidget {
  const BenchmarkControlPanel({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final BenchmarkConfig config;
  final ValueChanged<BenchmarkConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key(BenchmarkTestKeys.panel),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Benchmark',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in DatasetSize.values)
                _Chip(
                  key: Key(_datasetKey(size)),
                  label: '${size.label} candles',
                  selected: config.datasetSize == size,
                  onTap: () => onChanged(config.copyWith(datasetSize: size)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Live data', style: theme.textTheme.bodyMedium),
              Switch(
                key: const Key(BenchmarkTestKeys.liveDataToggle),
                value: config.liveDataEnabled,
                onChanged: (value) =>
                    onChanged(config.copyWith(liveDataEnabled: value)),
              ),
            ],
          ),
          if (config.liveDataEnabled)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rate in StreamRate.values)
                  _Chip(
                    key: Key(_streamRateKey(rate)),
                    label: rate.label,
                    selected: config.streamRate == rate,
                    onTap: () => onChanged(config.copyWith(streamRate: rate)),
                  ),
              ],
            ),
        ],
      ),
    );
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
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
    );
  }
}
