import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:neocharts_exampleapp/data/repositories/uni_chart_repository.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

const _buyColor = Color(0xFF00A651);
const _sellColor = Color(0xFFFF1F4B);

/// UniChart demo: a host quote dashboard (live quote header, embedded
/// `NeoChartPage.uni`, day stats, Buy / Sell). Each chart action (and each Buy / Sell tap) shows
/// a snackbar where a real host would open its own order pad or editor.
class UniChartScreen extends StatefulWidget {
  const UniChartScreen({super.key, required this.host});

  /// Mock data and line streams, wrapped in a [UniChartRepository]. Disposed
  /// by the page when it unmounts; never reuse one across opens.
  final NeoChartsRepository host;

  @override
  State<UniChartScreen> createState() => _UniChartScreenState();
}

class _UniChartScreenState extends State<UniChartScreen> {
  late final _uni = UniChartRepository(base: widget.host, onAction: _show);

  void _show(String action) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(action)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _uni.symbol.id,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // The chart sizes itself to its panels; the page scrolls, not the chart.
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QuoteHeader(symbol: _uni.symbol, quote: _uni.quote),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  // The extra height goes to the main panel; sub-panels
                  // grow the card past it and the page scrolls.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height * 0.55,
                    ),
                    child: NeoChartPage.uni(
                      host: _uni,
                      supportedResolutions: demoResolutions,
                      nativeResolutions: const ['1', '1D'],
                      onTrade: _uni.onTrade,
                      orders: _uni,
                      oco: _uni,
                      positions: _uni,
                      alerts: _uni,
                    ),
                  ),
                ),
              ),
            ),
            _DayStats(precision: _uni.symbol.precision, quote: _uni.quote),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _TradeButton(
                  label: 'Buy',
                  color: _buyColor,
                  onPressed: () => _show('Buy tapped -- host order pad'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TradeButton(
                  label: 'Sell',
                  color: _sellColor,
                  onPressed: () => _show('Sell tapped -- host order pad'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteHeader extends StatelessWidget {
  const _QuoteHeader({required this.symbol, required this.quote});

  final SymbolInfo symbol;
  final ValueListenable<DayQuote?> quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${symbol.name} · ${symbol.exchange}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder(
            valueListenable: quote,
            builder: (context, quote, _) {
              final ltpStyle = theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              );
              if (quote == null) return Text('--', style: ltpStyle);

              final change = quote.ltp - quote.prevClose;
              final percent = quote.prevClose == 0
                  ? 0.0
                  : change / quote.prevClose * 100;
              final sign = change >= 0 ? '+' : '';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    quote.ltp.toStringAsFixed(symbol.precision),
                    style: ltpStyle,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$sign${change.toStringAsFixed(symbol.precision)} '
                    '($sign${percent.toStringAsFixed(2)}%)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: change >= 0 ? _buyColor : _sellColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayStats extends StatelessWidget {
  const _DayStats({required this.precision, required this.quote});

  final int precision;
  final ValueListenable<DayQuote?> quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ValueListenableBuilder(
        valueListenable: quote,
        builder: (context, quote, _) {
          String format(double? value) =>
              value?.toStringAsFixed(precision) ?? '--';

          return Row(
            children: [
              for (final (label, value) in [
                ('Open', quote?.open),
                ('High', quote?.high),
                ('Low', quote?.low),
                ('Prev close', quote?.prevClose),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        format(value),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TradeButton extends StatelessWidget {
  const _TradeButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
