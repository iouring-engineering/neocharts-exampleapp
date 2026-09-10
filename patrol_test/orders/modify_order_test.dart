import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/order_type.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';
import 'orders_test_helpers.dart';

// Modify order flow:
//   - Opened from an open order's Modify button; pre-fills price/trigger/qty
//     from the underlying order.
//   - Order type toggle (MKT/LMT/SL) governs which fields are shown/editable
//     and which client-side validation runs:
//       market   -> qty only
//       limit    -> qty + price
//       stopLoss -> qty + price + trigger
//   - On MODIFY: validation failure shows a top snackbar and leaves the pad
//     open; validation success dispatches the modification and pops
//     immediately (there is no in-pad loading/success/failure UI beyond
//     that).
//
// Every test here places a fresh market order first so there is always
// exactly one order to modify, independent of any other order in the
// account's history.
//
// Every test also leaves the modify pad closed before finishing (even ones
// that don't otherwise need to), so a fresh pumpWidget() for the next test
// doesn't race a still-open pad's own teardown.

void main() {
  group('Orders — modify pad', () {
    patrolTest('modify pad opens with pre-filled price and quantity', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: true);
      await openModifyPadForFirstOrder($);

      expect(find.text('MODIFY'), findsOneWidget);
      expect(find.text('NIFTY 50'), findsWidgets);
      expect(
        $.tester.widget<TextField>(modifyPadPriceField()).controller!.text,
        isNotEmpty,
      );
      expect(
        $.tester.widget<TextField>(modifyPadQtyField()).controller!.text,
        isNotEmpty,
      );

      await tapOutsideModal($);
    });

    patrolTest('switching order type to Limit makes the price field editable', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: true);
      await openModifyPadForFirstOrder($);

      // Placed as a market order, so the pad opens with price read-only.
      expect(
        $.tester.widget<TextField>(modifyPadPriceField()).readOnly,
        isTrue,
      );

      await tapOrderTypeChip($, OrderType.limit);

      expect(
        $.tester.widget<TextField>(modifyPadPriceField()).readOnly,
        isFalse,
      );

      await tapOutsideModal($);
    });

    patrolTest(
      'switching order type to Stop Loss reveals the trigger price field',
      ($) async {
        await openChartWithMock($);
        await placeMarketOrder($, isBuy: true);
        await openModifyPadForFirstOrder($);

        expect(find.text('TRG'), findsNothing);

        await tapOrderTypeChip($, OrderType.stopLoss);

        expect(find.text('TRG'), findsOneWidget);

        await tapOutsideModal($);
      },
    );
  });

  group('Orders — modify validation', () {
    patrolTest(
      'clearing the quantity and tapping MODIFY shows a required-quantity error',
      ($) async {
        await openChartWithMock($);
        await placeMarketOrder($, isBuy: true);
        await openModifyPadForFirstOrder($);

        await clearField($, modifyPadQtyField());
        await tapModifySubmit($);

        await waitUntilPresent(
          $,
          find.text('Please enter the quantity'),
          timeout: const Duration(seconds: 5),
        );
        // Validation failure must not pop the pad.
        expect(find.text('MODIFY'), findsOneWidget);

        await tapOutsideModal($);
      },
    );

    patrolTest(
      'clearing the price on a limit order shows a required-price error',
      ($) async {
        await openChartWithMock($);
        await placeMarketOrder($, isBuy: true);
        await openModifyPadForFirstOrder($);

        await tapOrderTypeChip($, OrderType.limit);
        await clearField($, modifyPadPriceField());
        await tapModifySubmit($);

        await waitUntilPresent(
          $,
          find.text('Please enter the price'),
          timeout: const Duration(seconds: 5),
        );
        expect(find.text('MODIFY'), findsOneWidget);

        await tapOutsideModal($);
      },
    );

    patrolTest(
      'clearing the trigger price on a stop-loss order shows a required-trigger error',
      ($) async {
        await openChartWithMock($);
        await placeMarketOrder($, isBuy: true);
        await openModifyPadForFirstOrder($);

        await tapOrderTypeChip($, OrderType.stopLoss);
        $.tester.widget<TextField>(modifyPadPriceField()).controller!.text =
            '100';
        await $.pumpAndSettle();
        await clearField($, modifyPadTriggerField());
        await tapModifySubmit($);

        await waitUntilPresent(
          $,
          find.text('Please enter the trigger price'),
          timeout: const Duration(seconds: 5),
        );
        expect(find.text('MODIFY'), findsOneWidget);

        await tapOutsideModal($);
      },
    );
  });

  group('Orders — modify submit and close', () {
    patrolTest('submitting the pre-filled (valid) values closes the pad', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: true);
      await openModifyPadForFirstOrder($);

      // Pre-filled values mirror the real order, so they're already valid
      // -- MODIFY should pass validation and pop without editing anything.
      await tapModifySubmit($);

      expect(find.text('MODIFY'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest(
      'closing the modify pad by tapping outside leaves the order unchanged',
      ($) async {
        await openChartWithMock($);
        await placeMarketOrder($, isBuy: true);
        await openModifyPadForFirstOrder($);

        await tapOutsideModal($);

        expect(find.text('MODIFY'), findsNothing);
        // The order is still open and modifiable.
        expect(findAnyOrderModifyBtn(), findsWidgets);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      },
    );
  });
}
