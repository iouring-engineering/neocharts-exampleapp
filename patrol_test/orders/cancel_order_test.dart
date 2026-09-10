import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';
import 'orders_test_helpers.dart';

// Cancel order flow:
//   - Opened from an open order's Cancel button as a confirmation dialog
//     showing the order's side/symbol/quantity summary.
//   - "Keep Order" and an outside-barrier tap both dismiss without
//     cancelling (dismissible barrier by default).
//   - The confirm button (also labelled "Cancel Order") dispatches the
//     cancellation and pops immediately -- there is no client-side
//     validation and no loading/error UI on this path, so there is no
//     "cancellation failed" state to exercise from the UI.
//
// Every test places a fresh market order first so there is always at least
// one open order to act on.

void main() {
  group('Orders — cancel dialog', () {
    patrolTest(
      'cancel dialog shows the confirmation prompt and order summary',
      ($) async {
        await openChartWithMock($);
        await placeMarketOrder($, isBuy: true);
        await openCancelDialogForFirstOrder($);

        expect(find.text('Cancel Order'), findsWidgets);
        expect(
          find.text('Are you sure you want to cancel this order?'),
          findsOneWidget,
        );
        // Order summary line reads "Qty <fill> / <net>".
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && (w.data?.startsWith('Qty') ?? false),
          ),
          findsOneWidget,
        );
        expect(find.text('NIFTY 50'), findsWidgets);
      },
    );

    patrolTest('"Keep Order" dismisses the dialog without cancelling', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: true);
      await openCancelDialogForFirstOrder($);

      await tapCancelDialogKeep($);

      expect(
        find.text('Are you sure you want to cancel this order?'),
        findsNothing,
      );
      expect(findAnyOrderCancelBtn(), findsWidgets);
    });

    patrolTest('tapping outside the dialog dismisses it without cancelling', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: true);
      await openCancelDialogForFirstOrder($);

      await tapOutsideModal($);

      expect(
        find.text('Are you sure you want to cancel this order?'),
        findsNothing,
      );
      expect(findAnyOrderCancelBtn(), findsWidgets);
    });

    patrolTest('confirming cancellation removes the order from the open list', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: true);
      await openCancelDialogForFirstOrder($);

      await tapCancelDialogConfirm($);

      await waitUntilAbsent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 15),
      );

      expect(findAnyOrderCancelBtn(), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });
}
