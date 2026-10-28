import 'package:flutter/material.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

/// UniChart page: symbol-name app bar, an empty
/// chart area, and Buy / Sell buttons at the bottom. No data or behaviour.
class UniChartScreen extends StatelessWidget {
  const UniChartScreen({
    super.key,
    required this.dataProvider,
    this.symbol = 'DRREDDY',
  });
  final ChartInterface dataProvider;

  final String symbol;

  static const _buyColor = Color(0xFF00A651);
  static const _sellColor = Color(0xFFFF1F4B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          symbol,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: NxtChartPage.uni(dataProvider: dataProvider),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: const [
              Expanded(
                child: _TradeButton(label: 'Buy', color: _buyColor),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _TradeButton(label: 'Sell', color: _sellColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeButton extends StatelessWidget {
  const _TradeButton({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: () {},
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
