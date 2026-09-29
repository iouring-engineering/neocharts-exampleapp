import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'positions_test_helpers.dart';

// Add position flow:
//   - Opened from an open position's Add icon; pre-fills qty (in lots) from
//     the position's own netQty, and price from the live LTP tick.
//   - Three submit buttons: "Execute at Market", "Execute at LTP" (limit,
//     priced at LTP), and "Execute" (whichever order type is selected).
//   - Validation only ever checks quantity here -- adding to a position has
//     no "qty exceeds available" concept, and price is always pre-filled/
//     valid by default.
//
// Every test seeds a fresh position first so there is always exactly one
// to add to.

void main() {
  group('Positions — add dialog', () {
    patrolTest('panel opens with a pre-filled, non-empty quantity', ($) async {
      await openChartWithMockPosition($);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());
      await tapPositionAddIcon($);

      expect(find.text('Add Position'), findsOneWidget);
      expect(find.text('NIFTY 50'), findsWidgets);
      expect(
        $.tester
            .widget<TextField>(fieldByKey(ChartTestKeys.addPositionQtyField))
            .controller!
            .text,
        isNotEmpty,
      );

      await tapOutsideModal($);
    });

    patrolTest('tapping outside the panel dismisses it without adding', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());
      await tapPositionAddIcon($);

      await tapOutsideModal($);

      expect(find.text('Add Position'), findsNothing);
    });
  });

  group('Positions — add validation', () {
    patrolTest(
      'clearing the quantity and tapping Execute shows a required-quantity error',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionAddIcon($);

        await clearField($, fieldByKey(ChartTestKeys.addPositionQtyField));
        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.addPositionExecuteBtn)),
        );
        await $.pumpAndSettle();

        await waitUntilPresent(
          $,
          find.text('Please enter the quantity'),
          timeout: const Duration(seconds: 5),
        );
        // Validation failure must not pop the panel.
        expect(find.text('Add Position'), findsOneWidget);

        await tapOutsideModal($);
      },
    );
  });

  group('Positions — add submit', () {
    patrolTest(
      'tapping "Execute at Market" with the pre-filled quantity closes the panel',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionAddIcon($);

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.addPositionExecuteMarketBtn)),
        );
        await $.pumpAndSettle();

        expect(find.text('Add Position'), findsNothing);
      },
    );

    patrolTest(
      'tapping "Execute at LTP" with the pre-filled quantity closes the panel',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionAddIcon($);

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.addPositionExecuteLtpBtn)),
        );
        await $.pumpAndSettle();

        expect(find.text('Add Position'), findsNothing);
      },
    );

    // NeoTapGuard wraps all three execute buttons in add_position_panel.dart
    // (the same _buidActionButton helper). Both taps are driven back-to-back
    // with no pump() in between -- the panel pops on a successful execute,
    // so pumping between taps would let the first tap's pop already start
    // removing the button before the second tap lands. Adding places a real
    // order alongside the position update, so the orders list is what
    // proves whether one or two executions actually went through.
    patrolTest('rapid double-tapping "Execute at Market" adds exactly once', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());
      await tapPositionAddIcon($);

      final executeBtn = find.byKey(
        Key(ChartTestKeys.addPositionExecuteMarketBtn),
      );
      await $.tester.tap(executeBtn);
      await $.tester.tap(executeBtn, warnIfMissed: false);
      await $.pumpAndSettle();

      expect(find.text('Add Position'), findsNothing);

      await closePositionsPanel($);
      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderModifyBtn(),
        timeout: const Duration(seconds: 20),
      );

      expect(findAnyOrderModifyBtn(), findsNWidgets(1));
      expect(findAnyOrderCancelBtn(), findsNWidgets(1));
    });
  });
}
