import 'package:flutter/material.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

class NxtScalperChartScreen extends StatelessWidget {
  const NxtScalperChartScreen({super.key, required this.dataProvider});

  final ChartInterface dataProvider;

  @override
  Widget build(BuildContext context) {
    return NxtChartPage(dataProvider: dataProvider, style: _demoStyle);
  }
}

// Demo brand colors for both modes -- see the theming docs for all 14 tokens.
const _demoColors = NxtChartColorOverrides(
  primary: Color(0xFF7B1FA2),
  bullish: Color(0xFF26A69A),
  bearish: Color(0xFFEF5350),
);
const _demoStyle = NxtChartStyle(
  lightColors: _demoColors,
  darkColors: _demoColors,
);
