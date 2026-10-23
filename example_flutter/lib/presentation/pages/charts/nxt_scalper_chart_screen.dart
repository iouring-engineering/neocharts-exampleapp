import 'package:flutter/material.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

const _homeKey = String.fromEnvironment('NEOCHARTS_HOME_KEY');

class NxtScalperChartScreen extends StatelessWidget {
  const NxtScalperChartScreen({super.key, required this.dataProvider});

  final ChartInterface dataProvider;

  @override
  Widget build(BuildContext context) {
    return NxtChartPage(
      dataProvider: dataProvider,
      homeKey: _homeKey.isEmpty ? null : _homeKey,
    );
  }
}
