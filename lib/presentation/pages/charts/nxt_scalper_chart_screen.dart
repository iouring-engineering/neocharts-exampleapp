import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/utils/nxt_chart_helper.dart';
import 'package:nxtchart/widgets.dart';

class NxtScalperChartScreen extends StatelessWidget {
  const NxtScalperChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NxtChartPage.scalper(
      dataProvider: NxtChartHelper(storageKey: 'scalper_chart'),
    );
  }
}
