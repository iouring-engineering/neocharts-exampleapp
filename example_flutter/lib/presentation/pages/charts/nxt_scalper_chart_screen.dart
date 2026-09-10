import 'package:flutter/material.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

class NxtScalperChartScreen extends StatelessWidget {
  const NxtScalperChartScreen({super.key, required this.dataProvider});

  final ChartInterface dataProvider;

  @override
  Widget build(BuildContext context) {
    return NxtChartPage(dataProvider: dataProvider);
  }
}
