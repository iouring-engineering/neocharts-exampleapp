import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/analysis_tab_types.dart';
import 'package:nxtchart/src/enums/oi_change_interval.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';
import 'analysis_test_helpers.dart';

// OI Change tab:
//   - NxtChartRepository.fetchOIChange returns real synthetic per-strike
//     call/put OI-change data, so this tab's chart and summary row render
//     live content -- not just the fallback "No data available" state.
//   - The expiry dropdown (same real-data-backed mechanism as OI
//     Analysis's) and the interval chip row (OIChangeInterval.values) are
//     both genuinely testable.
//
// Every test opens a fresh chart and switches straight to the OI Change
// tab.

void main() {
  group('Analysis — OI Change tab', () {
    patrolTest('renders with real data by default', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.oiChange);

      expect(find.text('No data available'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });

    patrolTest('the expiry dropdown offers real expiries and can select one', (
      $,
    ) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.oiChange);

      await $.tester.tap(find.byKey(Key(ChartTestKeys.oiChangeExpiryDropdown)));
      await $.pumpAndSettle();

      final option = findByKeyPrefix('chart_oi_change_expiry_option_');
      await waitUntilPresent($, option);
      expect(option, findsWidgets);

      await $.tester.tap(option.first);
      await $.pumpAndSettle();

      expect(find.text('No data available'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });

    patrolTest('every interval chip is selectable without error', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.oiChange);

      for (final interval in OIChangeInterval.values) {
        await tapOiChangeIntervalChip($, interval);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      }

      await tapAnalysisClose($);
    });
  });
}
