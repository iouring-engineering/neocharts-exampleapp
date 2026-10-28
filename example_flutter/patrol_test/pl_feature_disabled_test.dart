import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/presentation/pages/pl/pnl_card.dart';
import 'package:nxtchart/src/presentation/widgets/market_clock.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import 'helpers.dart';

// NxtChartFeature.pl disabled (NxtChartPage.disabledFeatures: ['pl']):
//   - Drops the drawer's P&L tab (see ChartDrawerTypes/_buildTabItems).
//   - Swaps MarketClockOrPnlCard's MarketClock pill for a PnlCard pill
//     instead, since the dropped tab would otherwise be the only place to
//     see total P&L -- see market_clock.dart.
//   - Neither MarketClock nor PnlCard carries a Key, so both are located by
//     widget type rather than ChartTestKeys.

void main() {
  group('P&L — pl feature disabled', () {
    patrolTest('hides the market clock pill in favour of a P&L pill', (
      $,
    ) async {
      await openChartAndAwaitLoad($, disabledFeatures: ['pl']);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.byType(PnlCard), findsOneWidget);
      expect(find.byType(MarketClock), findsNothing);
    });

    patrolTest('drops the drawer\'s P&L tab', ($) async {
      await openChartAndAwaitLoad($, disabledFeatures: ['pl']);

      await tapByKeyCentre(
        $,
        ChartTestKeys.hamburgerBtn,
        localPoint: const Offset(25, 15),
      );
      await $.pumpAndSettle();

      expect(find.byKey(Key(ChartTestKeys.drawerTab('pl'))), findsNothing);
    });

    patrolTest(
      'shows the market clock pill and the drawer tab when pl is left enabled',
      ($) async {
        await openChartAndAwaitLoad($);

        expect(find.byType(MarketClock), findsOneWidget);
        expect(find.byType(PnlCard), findsNothing);

        await tapByKeyCentre(
          $,
          ChartTestKeys.hamburgerBtn,
          localPoint: const Offset(25, 15),
        );
        await $.pumpAndSettle();

        expect(find.byKey(Key(ChartTestKeys.drawerTab('pl'))), findsOneWidget);
      },
    );
  });
}
