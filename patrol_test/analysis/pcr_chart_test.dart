import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/analysis_tab_types.dart';
import 'package:nxtchart/src/enums/pcr_range.dart';

import 'analysis_test_helpers.dart';

// PCR tab:
//   - NxtChartRepository.fetchPcrIntraday is fully implemented with real
//     synthetic data (unlike OI Analysis/OI Change), so this tab renders
//     real chart content by default, not the empty state.
//   - A range-filter chip row (PcrRange.values) picks how many strikes
//     either side of ATM to include; selecting one re-renders from the
//     same already-fetched history (no re-fetch).
//
// Every test opens a fresh chart and switches straight to the PCR tab.

void main() {
  group('Analysis — PCR chart', () {
    patrolTest('renders with real data by default', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.pcr);

      // Legend row shows the underlying name alongside the "PCR" label.
      expect(find.text('PCR'), findsWidgets);
      expect(find.text('No data available'), findsNothing);

      await tapAnalysisClose($);
    });

    patrolTest('every range chip is selectable without error', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.pcr);

      for (final range in PcrRange.values) {
        await tapPcrRangeChip($, range);
        expect(find.text('No data available'), findsNothing);
      }

      await tapAnalysisClose($);
    });
  });
}
