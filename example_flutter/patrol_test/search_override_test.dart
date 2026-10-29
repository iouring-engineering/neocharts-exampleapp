import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/interface/market_data_interface.dart';
import 'package:nxtchart/src/presentation/blocs/chart_bloc.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:nxtchart/widgets.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// `NeoChartWidgetOverrides.onOpenSearch`: a host that supplies it gets the
// search tap instead of the built-in panel and answers with a symbol id;
// one that doesn't keeps the built-in panel.

String? chartedId(PatrolIntegrationTester $) => $.tester
    .element(find.byKey(Key(ChartTestKeys.symbolSearchBtn)))
    .read<ChartBloc>()
    .state
    .dataProvider
    ?.parseSymInfo
    .id;

void main() {
  group('Host search override', () {
    patrolTest('tap calls the host, not the built-in panel; pick loads it', (
      $,
    ) async {
      var opened = 0;
      void Function(String)? pick;
      await openChartWithOverridesAndAwaitLoad(
        $,
        NeoChartWidgetOverrides(
          onOpenSearch: (onSymbolSelected) {
            opened++;
            pick = onSymbolSelected;
          },
        ),
      );
      final before = chartedId($);

      await openSymbolSearch($);
      expect(opened, 1);
      expect(find.byKey(Key(ChartTestKeys.symbolSearchField)), findsNothing);
      expect(chartedId($), before);

      pick!('INDIAVIX');
      await $.pumpAndSettle();
      expect(chartedId($), 'INDIAVIX');
    });

    patrolTest('backing out leaves the chart as it was', ($) async {
      await openChartWithOverridesAndAwaitLoad(
        $,
        NeoChartWidgetOverrides(onOpenSearch: (_) {}),
      );
      final before = chartedId($);

      await openSymbolSearch($);
      await $.pumpAndSettle();

      expect(chartedId($), before);
    });

    patrolTest('without an override the built-in search opens', ($) async {
      await openChartAndAwaitLoad($);

      await openSymbolSearch($);

      expect(find.byKey(Key(ChartTestKeys.symbolSearchField)), findsOneWidget);
    });
  });
}
