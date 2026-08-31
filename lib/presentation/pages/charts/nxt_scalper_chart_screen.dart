import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/data/repositories/nxt_chart_repository.dart';
import 'package:nxtchart/widgets.dart';

class NxtScalperChartScreen extends StatelessWidget {
  const NxtScalperChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NxtChartPage.scalper(
      dataProvider: NxtChartRepository(storageKey: 'scalper_chart'),
    );
  }
}
