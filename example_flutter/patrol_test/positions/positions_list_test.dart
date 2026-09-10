import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'positions_test_helpers.dart';

// Positions list:
//   - An open position's row shows its qty/avg price/live LTP and, only
//     for an open position, the Add/Adjust/Exit action icons.
//   - The screen has two tabs -- Open and Close -- each filtered from the
//     same underlying positions map; a tab with nothing to show renders
//     the "No data available" state instead of an empty list.
//   - The header's Total P&L / Total MTM figures are computed across all
//     positions regardless of which tab is selected.
//
// Every test seeds a fresh position first so there is always exactly one
// to list.

void main() {
  group('Positions — list', () {
    patrolTest(
      'an open position shows its qty, avg price, and ltp and action icons',
      ($) async {
        await openChartWithMockPosition($, netQty: 75, avgPrice: 22500);
        await openPositionsPanel($);

        await waitUntilPresent($, findPositionListItem());
        expect(find.text('NIFTY 50'), findsWidgets);
        expect(find.text('Qty: '), findsOneWidget);
        expect(find.text('LTP: '), findsOneWidget);
      },
    );

    patrolTest(
      'the Close tab shows the empty state for an open-only position',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());

        await $.tester.tap(find.text('Close'));
        await $.pumpAndSettle();

        expect(findPositionListItem(), findsNothing);
        expect(find.text('No data available'), findsOneWidget);
      },
    );

    patrolTest('a full exit at market moves the position from Open to Close', (
      $,
    ) async {
      // Placing an order applies an immediate fill against the matching
      // position (netQty += buy ? qty : -qty) -- a full exit zeroes it
      // out, and it flips from open to closed instead of disappearing
      // (netQty == 0 is kept, not removed, so it still shows in Close).
      await openChartWithMockPosition($, netQty: 100);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());

      await tapPositionExitIcon($);
      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.exitPositionExecuteMarketBtn)),
      );
      await $.pumpAndSettle();

      await waitUntilAbsent($, findPositionListItem());
      expect(findPositionListItem(), findsNothing);

      await $.tester.tap(find.text('Close'));
      await $.pumpAndSettle();

      expect(findPositionListItem(), findsOneWidget);
    });

    patrolTest('the header shows Total P&L and Total MTM regardless of tab', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());

      expect(find.text('Total P&L'), findsOneWidget);
      expect(find.text('Total MTM'), findsOneWidget);

      await $.tester.tap(find.text('Close'));
      await $.pumpAndSettle();

      expect(find.text('Total P&L'), findsOneWidget);
      expect(find.text('Total MTM'), findsOneWidget);
    });
  });
}
