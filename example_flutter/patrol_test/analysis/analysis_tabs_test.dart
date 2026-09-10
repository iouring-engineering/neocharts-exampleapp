import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/analysis_tab_types.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';
import 'analysis_test_helpers.dart';

// Analysis panel shell:
//   - Opened from the trading drawer's "analysis" tab, same mechanism as
//     orders/positions/alerts.
//   - Header shows the underlying's name and live LTP; a close button
//     dismisses the panel.
//   - A 6-tab bar (Price/OI/OI Change/ATM Straddle/PCR/ATM IV) switches
//     the body between the 6 chart widgets, each covered in its own file.
//
// Every test opens a fresh chart first.

void main() {
  group('Analysis — panel', () {
    patrolTest('opens with the underlying name and LTP in the header', (
      $,
    ) async {
      await openChartWithMock($);
      await openAnalysisPanel($);

      expect(find.text('NIFTY 50'), findsWidgets);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });

    patrolTest('the close button dismisses the panel', ($) async {
      await openChartWithMock($);
      await openAnalysisPanel($);
      expect(find.byKey(Key(ChartTestKeys.analysisCloseBtn)), findsOneWidget);

      await tapAnalysisClose($);

      expect(find.byKey(Key(ChartTestKeys.analysisCloseBtn)), findsNothing);
    });
  });

  group('Analysis — tab switching', () {
    patrolTest('every tab is reachable and renders without error', ($) async {
      await openChartWithMock($);
      await openAnalysisPanel($);

      for (final tab in AnalysisTabTypes.values) {
        await tapAnalysisTab($, tab);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      }

      await tapAnalysisClose($);
    });
  });
}
