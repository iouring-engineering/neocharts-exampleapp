import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../helpers.dart';
import 'orders_test_helpers.dart';

// On-chart order marker: a draggable price line drawn for every open
// order, independent of the orders-list panel already covered by
// modify_order_test.dart / cancel_order_test.dart.
//   - Dragging its price line vertically opens the modify pad, pre-filled
//     with the dropped (tick-snapped) price -- the same pad the
//     orders-list Modify button opens, just via a different entry point.
//   - Tapping the tag's own label reveals a close ("X") button that opens
//     the same cancel confirmation dialog the orders-list Cancel button
//     does.
//
// Every test places a fresh market order first so there is always exactly
// one order (and therefore exactly one chart tag) to act on.

void main() {
  group('Orders — chart marker drag to modify', () {
    patrolTest('dragging the price line opens the modify pad, pre-filled', (
      $,
    ) async {
      await openChartWithMock($);
      await placeLimitOrder($, isBuy: true);
      await dragFirstOrderChartTag($);

      expect(find.text('MODIFY'), findsOneWidget);
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

    patrolTest('submitting the pad after a chart-line drag closes it', (
      $,
    ) async {
      await openChartWithMock($);
      await placeLimitOrder($, isBuy: true);
      await dragFirstOrderChartTag($);

      // The dropped price is already tick-snapped and nonzero, so this
      // passes validation without editing anything further.
      await tapModifySubmit($);

      expect(find.text('MODIFY'), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });

    patrolTest(
      'dismissing the pad after a chart-line drag leaves the order open',
      ($) async {
        await openChartWithMock($);
        await placeLimitOrder($, isBuy: true);
        await dragFirstOrderChartTag($);

        await tapOutsideModal($);

        expect(find.text('MODIFY'), findsNothing);
        await openOrdersPanel($);
        expect(findAnyOrderModifyBtn(), findsWidgets);
      },
    );
  });

  group('Orders — chart marker close button', () {
    patrolTest(
      'reveals and opens the same cancel confirmation as the orders list',
      ($) async {
        await openChartWithMock($);
        await placeLimitOrder($, isBuy: true);
        await revealAndTapFirstOrderChartCloseBtn($);

        expect(find.text('Cancel Order'), findsWidgets);
        expect(
          find.text('Are you sure you want to cancel this order?'),
          findsOneWidget,
        );
      },
    );

    patrolTest('confirming cancellation removes the order and its chart tag', (
      $,
    ) async {
      await openChartWithMock($);
      await placeLimitOrder($, isBuy: true);
      await revealAndTapFirstOrderChartCloseBtn($);

      await tapCancelDialogConfirm($);

      await waitUntilAbsent(
        $,
        findAnyOrderChartTag(),
        timeout: const Duration(seconds: 15),
      );
      expect(findAnyOrderChartTag(), findsNothing);
      expect($(Key(ChartTestKeys.errorState)), findsNothing);
    });
  });
}
