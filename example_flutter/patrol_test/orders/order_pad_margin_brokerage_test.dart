import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/enums/order_action.dart';
import 'package:nxtchart/src/enums/order_type.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'orders_test_helpers.dart';

// Required margin / brokerage preview (OrderPadMarginBrokerageInfo):
//   - Shown below each of the order pad's BUY/SELL buttons as "Req: ₹X",
//     X being margin + brokerage for that side. Hidden (SizedBox.shrink())
//     until the first fetchMargin/fetchBrokerage reply lands.
//   - NxtChartRepository's fetchMargin/fetchBrokerage are pure mocks (see
//     nxt_chart_repository.dart): margin is the full order value (lots x
//     lotSize x ltp), or 20% of it for intraday -- neither depends on
//     Buy/Sell, so both sides always show the same total once populated.
//     Brokerage is 0.03% of notional, capped at ₹20, also side-agnostic.
//   - Recomputed immediately on a qty-stepper tap (OrderPadQtySelector's
//     _setLots), and recomputed (debounced 400ms) while typing a Limit
//     price.

void main() {
  group('Orders — order pad margin and brokerage preview', () {
    patrolTest(
      'shows a required-margin total for both BUY and SELL once loaded',
      ($) async {
        await openChartWithMock($);
        await openOrderPad($);
        await tapOrderTypeChip($, OrderType.market);

        await waitUntilPresent($, marginBrokerageInfo(OrderAction.buy));
        await waitUntilPresent($, marginBrokerageInfo(OrderAction.sell));

        expect(marginBrokerageText($, OrderAction.buy), isNotEmpty);
        expect(marginBrokerageText($, OrderAction.sell), isNotEmpty);
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      },
    );

    patrolTest(
      'BUY and SELL show the same total since the mock margin is side-agnostic',
      ($) async {
        await openChartWithMock($);
        await openOrderPad($);
        await tapOrderTypeChip($, OrderType.market);

        await waitUntilPresent($, marginBrokerageInfo(OrderAction.buy));
        await waitUntilPresent($, marginBrokerageInfo(OrderAction.sell));

        final buyText = marginBrokerageText($, OrderAction.buy);
        final sellText = marginBrokerageText($, OrderAction.sell);

        expect(buyText, equals(sellText));
      },
    );

    patrolTest(
      'incrementing the qty stepper updates the required-margin total',
      ($) async {
        await openChartWithMock($);
        await openOrderPad($);
        await tapOrderTypeChip($, OrderType.market);

        await waitUntilPresent($, marginBrokerageInfo(OrderAction.buy));
        final before = marginBrokerageText($, OrderAction.buy);

        await $.tester.tap(find.byIcon(Icons.add).first);
        await $.pumpAndSettle();

        final after = marginBrokerageText($, OrderAction.buy);
        expect(after, isNot(equals(before)));
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      },
    );

    patrolTest(
      'editing the Limit price updates the required-margin total after the debounce',
      ($) async {
        await openChartWithMock($);
        await openOrderPad($);
        await tapOrderTypeChip($, OrderType.limit);

        await waitUntilPresent($, marginBrokerageInfo(OrderAction.buy));
        final before = marginBrokerageText($, OrderAction.buy);

        final priceField = orderPadPriceField();
        final currentPrice = $.tester
            .widget<TextField>(priceField)
            .controller!
            .text;
        final bumpedPrice = (double.parse(currentPrice) + 50).toStringAsFixed(
          2,
        );

        await $.tester.enterText(priceField, bumpedPrice);
        // _scheduleMarginSync debounces 400ms from the last edit.
        await $.tester.pump(const Duration(milliseconds: 500));
        await $.pumpAndSettle();

        final after = marginBrokerageText($, OrderAction.buy);
        expect(after, isNot(equals(before)));
        expect($(Key(ChartTestKeys.errorState)), findsNothing);
      },
    );
  });
}
