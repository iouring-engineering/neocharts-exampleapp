import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/analysis_tab_types.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'analysis_test_helpers.dart';

// Price, ATM Straddle, and ATM IV tabs: none of the three has any
// interactive control of its own (no dropdown/switch/chip row, unlike PCR/
// OI Analysis/OI Change) -- each is just a live chart plus a static
// two-item legend, so these are smoke tests confirming each renders with
// real data and without error, mirroring the "opens without error" style
// used for the base trading panels elsewhere in this suite.
//
// Price chart data comes from the market data loaded once when the
// analysis panel opens, independent of tab selection; ATM Straddle/IV come
// from NxtChartRepository.fetchAtmStraddleIntraday/fetchAtmIvIntraday,
// both fully implemented with real synthetic data.
//
// Every test opens a fresh chart first.

void main() {
  group('Analysis — Price tab', () {
    patrolTest('renders with real data by default', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.price);

      expect(find.text('No data available'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });
  });

  group('Analysis — ATM Straddle tab', () {
    patrolTest('renders with real data by default', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.atmStraddle);

      expect(find.text('No data available'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });
  });

  group('Analysis — ATM IV tab', () {
    patrolTest('renders with real data by default', ($) async {
      await openChartWithMock($);
      await openAnalysisTab($, AnalysisTabTypes.atmIV);

      expect(find.text('No data available'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await tapAnalysisClose($);
    });
  });
}
