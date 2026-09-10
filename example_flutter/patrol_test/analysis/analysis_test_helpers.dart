import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/analysis_tab_types.dart';
import 'package:nxtchart/src/enums/oi_change_interval.dart';
import 'package:nxtchart/src/enums/pcr_range.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';

// Shared setup/finder helpers for the Analysis Patrol suite (tabs, PCR, OI
// Analysis, OI Change, ATM Straddle, ATM IV, Price).
//
// Runs against NxtChartRepository, the app's own default -- no
// interfaceOverride needed here (unlike positions/alerts), since no
// per-test seeding is required: every analysis fetch (fetchPcrIntraday,
// fetchAtmStraddleIntraday, fetchAtmIvIntraday, fetchOIAnalysis,
// fetchOIChange) plus loadData/optionSymbols (which the price chart and
// every expiry dropdown depend on) are all fully implemented with real
// synthetic data.
//
// Every interactive element in the analysis panel carries a real
// ChartTestKeys entry -- every finder here locates by key, not by
// text/type/structure.

Future<void> openChartWithMock(PatrolIntegrationTester $) async {
  await openChartAndAwaitLoad($);
}

// The analysis panel's tab bar scrolls horizontally -- with 6 tabs, the
// later ones (pcr, atmIV) sit outside the panel's own visible width and
// need scrolling into view before a tap lands on them.
Future<void> tapAnalysisTab(
  PatrolIntegrationTester $,
  AnalysisTabTypes tab,
) async {
  final finder = find.byKey(Key(ChartTestKeys.analysisTab(tab.name)));
  await $.tester.ensureVisible(finder);
  await $.pumpAndSettle();
  await $.tester.tap(finder);
  await $.pumpAndSettle();
}

Future<void> tapAnalysisClose(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.analysisCloseBtn)));
  await $.pumpAndSettle();
}

// Opens the drawer, navigates to the analysis tab, then selects [tab] --
// AnalysisTabTypes.price is the tab view's own initial selection, so it
// needs no extra tap; every other tab does.
Future<void> openAnalysisTab(
  PatrolIntegrationTester $,
  AnalysisTabTypes tab,
) async {
  await openAnalysisPanel($);
  if (tab != AnalysisTabTypes.price) {
    await tapAnalysisTab($, tab);
  }
}

// The OI Analysis/OI Change expiry dropdown's own overlay rows are keyed
// by the exact expiry date string, which is date-derived (relative to
// "now" in NxtChartRepository.optionSymbols) -- there's no fixed literal
// to key a *specific* expiry off, so helpers.dart's findByKeyPrefix is used
// instead; there's only ever one expiry dropdown open at a time in these
// tests, so matching any option by prefix is unambiguous.

Future<void> selectFirstOiAnalysisExpiry(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.oiAnalysisExpiryDropdown)));
  await $.pumpAndSettle();
  final option = findByKeyPrefix('chart_oi_analysis_expiry_option_');
  await waitUntilPresent($, option);
  await $.tester.tap(option.first);
  await $.pumpAndSettle();
}

Future<void> selectFirstOiChangeExpiry(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.oiChangeExpiryDropdown)));
  await $.pumpAndSettle();
  final option = findByKeyPrefix('chart_oi_change_expiry_option_');
  await waitUntilPresent($, option);
  await $.tester.tap(option.first);
  await $.pumpAndSettle();
}

Future<void> tapOiChangeIntervalChip(
  PatrolIntegrationTester $,
  OIChangeInterval interval,
) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.oiChangeIntervalChip(interval.name))),
  );
  await $.pumpAndSettle();
}

Future<void> tapPcrRangeChip(PatrolIntegrationTester $, PcrRange range) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.pcrRangeChip(range.name))));
  await $.pumpAndSettle();
}
