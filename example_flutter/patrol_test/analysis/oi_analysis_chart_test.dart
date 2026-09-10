import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/analysis_tab_types.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';
import 'analysis_test_helpers.dart';

// OI Analysis tab:
//   - NxtChartRepository.fetchOIAnalysis returns real synthetic per-strike
//     call/put OI (plus change/prevOi) data, so this tab's chart, legend,
//     and summary row all render live content -- not just the fallback
//     "No data available" state.
//   - The expiry dropdown's options come from the app's own real synthetic
//     option-chain data.
//   - The "Show change in OI" switch is independent of both.
//
// Every test opens a fresh chart and switches straight to the OI Analysis
// tab.

void main() {
  group('Analysis — OI Analysis tab', () {
    patrolTest('renders with real data by default', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.oiAnalysis);

      expect(find.text('No data available'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });

    patrolTest('the expiry dropdown offers real expiries and can select one', (
      $,
    ) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.oiAnalysis);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.oiAnalysisExpiryDropdown)),
      );
      await $.pumpAndSettle();

      final option = findByKeyPrefix('chart_oi_analysis_expiry_option_');
      await waitUntilPresent($, option);
      expect(option, findsWidgets);

      await $.tester.tap(option.first);
      await $.pumpAndSettle();

      // Selecting an expiry re-dispatches the fetch -- the panel stays
      // open and the chart keeps rendering real data.
      expect(find.text('No data available'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });

    patrolTest('toggling "Show change in OI" does not error', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.oiAnalysis);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.oiAnalysisShowChangeSwitch)),
      );
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });
  });
}
