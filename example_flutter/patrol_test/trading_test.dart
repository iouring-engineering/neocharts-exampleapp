import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'helpers.dart';

void main() {
  group('Trading — panels', () {
    patrolTest('orders panel opens without error', ($) async {
      await openChartAndAwaitLoad($);
      await openOrdersPanel($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      // The drawer popup content shows the "Orders" header.
      expect(find.text('Orders'), findsWidgets);
    });

    patrolTest('positions panel opens without error', ($) async {
      await openChartAndAwaitLoad($);
      await openPositionsPanel($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.text('Positions'), findsWidgets);
    });

    patrolTest('P&L panel opens without error', ($) async {
      await openChartAndAwaitLoad($);
      await $(Key(ChartTestKeys.hamburgerBtn)).tap();
      await $.pumpAndSettle();
      await $(Key(ChartTestKeys.drawerTab('pl'))).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Trading — order pad', () {
    patrolTest('order pad shows BUY and SELL on chart tap', ($) async {
      await openChartAndAwaitLoad($);
      await openOrderPad($);

      expect($(Key(ChartTestKeys.orderPadBuyBtn)), findsOneWidget);
      expect($(Key(ChartTestKeys.orderPadSellBtn)), findsOneWidget);
    });

    patrolTest('tapping BUY dismisses order pad', ($) async {
      await openChartAndAwaitLoad($);
      await openOrderPad($);

      await $(Key(ChartTestKeys.orderPadBuyBtn)).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.orderPadBuyBtn)), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('tapping SELL dismisses order pad', ($) async {
      await openChartAndAwaitLoad($);
      await openOrderPad($);

      await $(Key(ChartTestKeys.orderPadSellBtn)).tap();
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.orderPadSellBtn)), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });

  group('Trading — place order flow', () {
    patrolTest('placed buy order appears in orders list', ($) async {
      await openChartAndAwaitLoad($);

      // Place a market buy.
      await openOrderPad($);
      await $(Key(ChartTestKeys.orderPadBuyBtn)).tap();
      await $.pumpAndSettle();

      // Open orders panel and wait for the order to stream in.
      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 20),
      );

      expect(findAnyOrderCancelBtn(), findsWidgets);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('placed sell order appears in orders list', ($) async {
      await openChartAndAwaitLoad($);

      await openOrderPad($);
      await $(Key(ChartTestKeys.orderPadSellBtn)).tap();
      await $.pumpAndSettle();

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 20),
      );

      expect(findAnyOrderCancelBtn(), findsWidgets);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest('trade event snackbar appears after order placement', ($) async {
      await openChartAndAwaitLoad($);

      await openOrderPad($);
      await $(Key(ChartTestKeys.orderPadBuyBtn)).tap();
      await $.pumpAndSettle();

      // Wait up to 15 s for the feedback event to arrive and trigger the
      // snackbar.
      await waitUntilPresent(
        $,
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Order') ?? false),
        ),
        timeout: const Duration(seconds: 15),
      );

      // Any of: "Order placed", "Order rejected", or the app's own msg.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Order') ?? false),
        ),
        findsWidgets,
      );
    });
  });

  group('Trading — cancel order', () {
    patrolTest('cancel order dialog appears from orders list', ($) async {
      await openChartAndAwaitLoad($);

      // Place an order first so there is something to cancel.
      await openOrderPad($);
      await $(Key(ChartTestKeys.orderPadBuyBtn)).tap();
      await $.pumpAndSettle();

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 20),
      );

      // Tap the first cancel button.
      await $.tester.tap(findAnyOrderCancelBtn().first);
      await $.pumpAndSettle();

      // Confirmation dialog must appear.
      expect(find.text('Cancel Order'), findsWidgets);
      expect(
        find.text('Are you sure you want to cancel this order?'),
        findsOneWidget,
      );
    });

    patrolTest('confirming cancel removes order from list', ($) async {
      await openChartAndAwaitLoad($);

      await openOrderPad($);
      await $(Key(ChartTestKeys.orderPadBuyBtn)).tap();
      await $.pumpAndSettle();

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 20),
      );

      await $.tester.tap(findAnyOrderCancelBtn().first);
      await $.pumpAndSettle();

      // Tap "Cancel Order" confirm button in the dialog.
      await $.tester.tap(find.text('Cancel Order').last);
      await $.pumpAndSettle();

      // Order list should eventually clear.
      await waitUntilAbsent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 15),
      );

      expect(findAnyOrderCancelBtn(), findsNothing);
    });

    patrolTest('"Keep Order" dismisses cancel dialog without removing order', (
      $,
    ) async {
      await openChartAndAwaitLoad($);

      await openOrderPad($);
      await $(Key(ChartTestKeys.orderPadBuyBtn)).tap();
      await $.pumpAndSettle();

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderCancelBtn(),
        timeout: const Duration(seconds: 20),
      );

      await $.tester.tap(findAnyOrderCancelBtn().first);
      await $.pumpAndSettle();

      await $.tester.tap(find.text('Keep Order'));
      await $.pumpAndSettle();

      // Dialog gone, order still present.
      expect(
        find.text('Are you sure you want to cancel this order?'),
        findsNothing,
      );
      expect(findAnyOrderCancelBtn(), findsWidgets);
    });
  });

  group('Trading — modify order', () {
    patrolTest('modify pad opens from orders list', ($) async {
      await openChartAndAwaitLoad($);

      await openOrderPad($);
      await $(Key(ChartTestKeys.orderPadBuyBtn)).tap();
      await $.pumpAndSettle();

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        findAnyOrderModifyBtn(),
        timeout: const Duration(seconds: 20),
      );

      await $.tester.tap(findAnyOrderModifyBtn().first);
      await $.pumpAndSettle();

      // Modify pad shows "MODIFY" button.
      expect(find.text('MODIFY'), findsOneWidget);
    });
  });

  group('Trading — positions', () {
    patrolTest('positions panel streams data without error', ($) async {
      await openChartAndAwaitLoad($);
      await openPositionsPanel($);

      // Allow time for the positions stream first emission.
      await $.tester.pump(const Duration(seconds: 3));

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(find.text('Positions'), findsWidgets);
    });
  });
}
