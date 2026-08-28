import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/utils/nxt_chart_helper.dart';
import 'package:nxtchart/widgets.dart';

class NxtChartScreen extends StatelessWidget {
  const NxtChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NxtChartPage(
      dataProvider: NxtChartHelper(storageKey: 'single_chart'),
    );
  }
}
