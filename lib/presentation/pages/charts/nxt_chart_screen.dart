import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/data/repositories/nxt_chart_repository.dart';
import 'package:nxtchart/widgets.dart';

class NxtChartScreen extends StatelessWidget {
  const NxtChartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NxtChartPage(
      dataProvider: NxtChartRepository(storageKey: 'single_chart'),
    );
  }
}
