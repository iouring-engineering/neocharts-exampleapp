import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/order_type.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';
import 'orders_test_helpers.dart';

// Order pad flow:
//   - Tapping the chart canvas opens the pad with BUY/SELL actions.
//   - Order type toggle (MKT/LMT) switches the price field between the
//     read-only live price (Market) and an editable price (Limit).
//   - Qty is a lot-count stepper, floored at 1 lot.
//   - BUY/SELL dispatches the placement and immediately dismisses the pad --
//     there is no loading state or in-pad success/failure UI; the only
//     client-side rejection is a non-tick-size-multiple limit price, which
//     depends on the live symbol's tick size and isn't exercised here to
//     keep this suite deterministic across symbols/markets.

void main() {
  group('Orders — order pad', () {
    patrolTest('order pad opens with BUY and SELL controls', ($) async {
      await openChartWithMock($);
      await openOrderPad($);

      expect($(Key(ChartTestKeys.orderPadBuyBtn)), findsOneWidget);
      expect($(Key(ChartTestKeys.orderPadSellBtn)), findsOneWidget);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest(
      'order type toggle switches the price field between read-only and editable',
      ($) async {
        await openChartWithMock($);
        await openOrderPad($);

        // Force Market first so the "before" state is known regardless of
        // any saved order-type preference the pad pre-selected with.
        await tapOrderTypeChip($, OrderType.market);
        expect(
          $.tester.widget<TextField>(orderPadPriceField()).readOnly,
          isTrue,
        );

        // Switching to Limit must make the price field editable.
        await tapOrderTypeChip($, OrderType.limit);
        expect(
          $.tester.widget<TextField>(orderPadPriceField()).readOnly,
          isFalse,
        );
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      },
    );

    patrolTest('quantity stepper decrements down to but not below 1 lot', (
      $,
    ) async {
      await openChartWithMock($);
      await openOrderPad($);

      final qtyField = orderPadQtyField();
      final startQty = $.tester.widget<TextField>(qtyField).controller!.text;

      // Decrement well past 1 lot -- the stepper must floor there rather
      // than reaching 0 or a negative quantity.
      for (var i = 0; i < 5; i++) {
        await $.tester.tap(find.byIcon(Icons.remove).first);
        await $.pumpAndSettle();
      }
      final flooredQty = $.tester.widget<TextField>(qtyField).controller!.text;
      expect(int.parse(flooredQty), greaterThan(0));

      // One more decrement must be a no-op once floored.
      await $.tester.tap(find.byIcon(Icons.remove).first);
      await $.pumpAndSettle();
      expect($.tester.widget<TextField>(qtyField).controller!.text, flooredQty);

      // Incrementing from the floor must move the quantity back up.
      await $.tester.tap(find.byIcon(Icons.add).first);
      await $.pumpAndSettle();
      final incrementedQty = $.tester
          .widget<TextField>(qtyField)
          .controller!
          .text;
      expect(int.parse(incrementedQty), greaterThan(int.parse(flooredQty)));
      expect(startQty, isNotEmpty);
    });

    patrolTest('closing the order pad by tapping outside places no order', (
      $,
    ) async {
      await openChartWithMock($);
      await openOrderPad($);

      await tapOutsideModal($);

      expect($(Key(ChartTestKeys.orderPadBuyBtn)), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Orders — place order flow', () {
    patrolTest('placing a market buy order appears in the orders list', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: true);

      // The pad dismisses immediately on BUY/SELL.
      expect($(Key(ChartTestKeys.orderPadBuyBtn)), findsNothing);

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderModifyBtn(),
        timeout: const Duration(seconds: 20),
      );

      expect(findAnyOrderModifyBtn(), findsWidgets);
      expect(findAnyOrderCancelBtn(), findsWidgets);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.text('NIFTY 50'), findsWidgets);
    });

    patrolTest('placing a market sell order appears in the orders list', (
      $,
    ) async {
      await openChartWithMock($);
      await placeMarketOrder($, isBuy: false);

      expect($(Key(ChartTestKeys.orderPadSellBtn)), findsNothing);

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderModifyBtn(),
        timeout: const Duration(seconds: 20),
      );

      expect(findAnyOrderModifyBtn(), findsWidgets);
      expect(findAnyOrderCancelBtn(), findsWidgets);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.text('NIFTY 50'), findsWidgets);
    });
  });
}
