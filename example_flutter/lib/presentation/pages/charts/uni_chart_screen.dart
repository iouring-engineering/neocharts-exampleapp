import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/data/repositories/uni_chart_repository.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

/// UniChart page: symbol-name app bar, `NxtChartPage.uni`, and Buy / Sell
/// buttons at the bottom. Each chart action (and each Buy / Sell tap) shows
/// a snackbar where a real host would open its own order pad or editor.
class UniChartScreen extends StatefulWidget {
  const UniChartScreen({
    super.key,
    required this.dataProvider,
    this.symbol = 'DRREDDY',
  });

  /// Mock data and line streams, wrapped in a [UniChartRepository].
  final ChartInterface dataProvider;

  final String symbol;

  @override
  State<UniChartScreen> createState() => _UniChartScreenState();
}

class _UniChartScreenState extends State<UniChartScreen> {
  static const _buyColor = Color(0xFF00A651);
  static const _sellColor = Color(0xFFFF1F4B);

  late final _uni = UniChartRepository(
    base: widget.dataProvider,
    onAction: _show,
  );

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
          widget.symbol,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: NxtChartPage.uni(dataProvider: _uni),
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
