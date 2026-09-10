import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'positions_test_helpers.dart';

// Exit position flow:
//   - Opened from an open position's Exit icon; pre-fills quantity to the
//     position's full available qty (100%) and price from the live LTP
//     tick.
//   - A 25/50/75/100% selector rewrites the quantity field to that
//     fraction of the position.
//   - Validation additionally checks the entered quantity never exceeds
//     what's actually available to exit -- a check that only applies
//     here, not to add/adjust.
//   - Three submit buttons: "Exit at Market", "Exit at LTP" (limit, priced
//     at LTP), and "Exit" (whichever order type is selected). None of
//     these trip the OCO-cancel-on-exit interstitial in this suite -- that
//     only appears when an OCO order already exists for the position,
//     which nothing here creates.
//
// Every test seeds a fresh position first so there is always exactly one
// to exit.

void main() {
  group('Positions — exit dialog', () {
    patrolTest('panel opens with quantity pre-filled to the full position', (
      $,
    ) async {
      // A netQty that's a clean multiple of the mock's lot size (50) --
      // the 100% selector rounds to the nearest whole lot, so an unclean
      // netQty (e.g. 75, 1.5 lots) wouldn't land back on itself exactly.
      await openChartWithMockPosition($, netQty: 100);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());
      await tapPositionExitIcon($);

      expect(find.text('Exit Position'), findsOneWidget);
      expect(find.text('NIFTY 50'), findsWidgets);
      expect(
        $.tester
            .widget<TextField>(fieldByKey(ChartTestKeys.exitPositionQtyField))
            .controller!
            .text,
        '100',
      );

      await tapOutsideModal($);
    });

    patrolTest('the 50% selector halves the pre-filled quantity', ($) async {
      await openChartWithMockPosition($, netQty: 100);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());
      await tapPositionExitIcon($);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.exitPositionQtyPercent(50))),
      );
      await $.pumpAndSettle();

      expect(
        $.tester
            .widget<TextField>(fieldByKey(ChartTestKeys.exitPositionQtyField))
            .controller!
            .text,
        '50',
      );

      await tapOutsideModal($);
    });
  });

  group('Positions — exit validation', () {
    patrolTest(
      'entering more than the available quantity shows a qty-exceeds error',
      ($) async {
        await openChartWithMockPosition($, netQty: 75);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionExitIcon($);

        await setField(
          $,
          fieldByKey(ChartTestKeys.exitPositionQtyField),
          '150',
        );
        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.exitPositionExecuteBtn)),
        );
        await $.pumpAndSettle();

        await waitUntilPresent(
          $,
          find.text('Qty should not be more than available qty'),
          timeout: const Duration(seconds: 5),
        );
        expect(find.text('Exit Position'), findsOneWidget);

        await tapOutsideModal($);
      },
    );
  });

  group('Positions — exit submit', () {
    patrolTest(
      'tapping "Exit at Market" with the pre-filled quantity closes the panel',
      ($) async {
        await openChartWithMockPosition($, netQty: 100);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionExitIcon($);

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.exitPositionExecuteMarketBtn)),
        );
        await $.pumpAndSettle();

        expect(find.text('Exit Position'), findsNothing);
      },
    );

    patrolTest('a full exit at market places a corresponding sell order', (
      $,
    ) async {
      await openChartWithMockPosition($, netQty: 100);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());
      await tapPositionExitIcon($);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.exitPositionExecuteMarketBtn)),
      );
      await $.pumpAndSettle();

      // Exiting places a new (opposite-side) order, same as any other
      // order placement, alongside applying the fill to the position
      // itself (verified separately in positions_list_test.dart).
      await closePositionsPanel($);
      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 10),
      );
      expect(findAnyOrderCancelBtn(), findsWidgets);
    });
  });
}
