import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/enums/chart_indicator.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// Indicators requested for verification, by [ChartIndicator] enum name.
// Looked up at runtime (not as enum constants) so this file compiles on SDK
// branches that don't define every indicator; a missing one fails its own
// test with a clear reason instead of breaking compilation.
// Cumulative Volume Delta is not implemented in the SDK, so it has no entry.
const _indicatorNames = <String>[
  'cmf',
  'hv',
  'momentum',
  'netVolume',
  'obv',
  'zScore',
  'fisher',
  'efi',
  'trix',
  'coppock',
  'pvt',
  'nvi',
  'chaikinOsc',
  'pvo',
  'massIndex',
  'rvgi',
  'uo',
  'vortex',
  'rvi',
  'bollingerRsiTools',
  'keyLevel',
  'tsi',
  'rci',
  'crsi',
  'trendStrength',
  'premierRsi',
  'ultimateRsi',
  'smiErgodic',
  'smiErgodicOscillator',
  'premierStochastic',
  'waveTrend',
  'squeezeMomentum',
  'rciRibbon',
  'rsiDivergence',
];

void main() {
  group('Requested indicators', () {
    for (final name in _indicatorNames) {
      patrolTest('add and remove $name', ($) async {
        final matches = ChartIndicator.values.where((i) => i.name == name);
        expect(
          matches,
          isNotEmpty,
          reason: 'ChartIndicator.$name is not defined in this SDK version',
        );
        final indicator = matches.first;

        await openChartAndAwaitLoad($);

        await openIndicatorMenu($);
        final tab = indicator.type == IndicatorType.overlay
            ? ChartTestKeys.indicatorTabOverlay
            : ChartTestKeys.indicatorTabPanel;
        await $(Key(tab)).tap();
        await $.pumpAndSettle();

        // Lazy list: scroll in small, slow steps until the row is built.
        final row = $(Key(ChartTestKeys.indicatorBrowseRow(indicator.key)));
        final list = find.byType(ListView).last;
        for (var i = 0; i < 150; i++) {
          if (row.finder.evaluate().isNotEmpty) {
            await $.tester.ensureVisible(row.finder);
            await $.pump(const Duration(milliseconds: 300));
            break;
          }
          await $.tester.drag(list, const Offset(0, -60));
          await $.pump(const Duration(milliseconds: 300));
        }
        await $.pumpAndSettle();
        await row.tap();
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.legendRow(indicator.key))), findsOneWidget);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        // Remove via the Active view.
        await $(Key(ChartTestKeys.indicatorActiveLink)).tap();
        await $.pumpAndSettle();
        final active = $(Key(ChartTestKeys.indicatorActiveRow(indicator.key)));
        expect(active, findsOneWidget);
        await active.tap();
        await $.pumpAndSettle();

        expect($(Key(ChartTestKeys.legendRow(indicator.key))), findsNothing);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      });
    }
  });
}
