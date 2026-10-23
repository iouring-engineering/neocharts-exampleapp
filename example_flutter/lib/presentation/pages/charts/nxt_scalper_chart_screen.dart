import 'package:flutter/material.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

const _freePass = String.fromEnvironment('NEOCHARTS_FREE_PASS');

class NxtScalperChartScreen extends StatelessWidget {
  const NxtScalperChartScreen({super.key, required this.dataProvider});

  final ChartInterface dataProvider;

  @override
  Widget build(BuildContext context) {
    return NxtChartPage(
      dataProvider: dataProvider,
      freePass: _freePass.isEmpty ? null : _freePass,
    );
  }
}
