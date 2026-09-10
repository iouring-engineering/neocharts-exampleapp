import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/enums/order_type.dart';

import '../../helpers.dart';
import '../positions_test_helpers.dart';
import 'group_adjust_test_helpers.dart';

// Adjust-to item card, once a strike has been added via the option chain:
//   - Price field is read-only on Market, editable on Limit -- same
//     pattern as every other order-type-gated price field in this app
//     (order pad, modify pad, single-position adjust).
//   - Buy/Sell action buttons and the delete button are independent of
//     order type.
//
// Every test seeds a position, selects it, opens the option chain, and
// adds the first strike, so there is always exactly one adjust-to item to
// act on. Every test also closes the option chain (tapOutsideModal) before
// finishing -- see group_adjust_option_chain_test.dart's identical
// rationale.

void main() {
  group('Group adjust — item price field', () {
    patrolTest('the price field is read-only on Market and editable on Limit', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await openGroupAdjustOptionChain($);
      await tapFirstOptionChainStrikeCell($);

      expect(
        $.tester.widget<TextField>(findAnyAdjustItemPriceField()).readOnly,
        isTrue,
      );

      await tapGroupAdjustOrderTypeChip($, OrderType.limit.name);

      expect(
        $.tester.widget<TextField>(findAnyAdjustItemPriceField()).readOnly,
        isFalse,
      );

      await tapOutsideModal($);
    });
  });

  group('Group adjust — item actions', () {
    patrolTest(
      'the Buy and Sell action buttons are both tappable without error',
      ($) async {
        await openChartWithMockPosition($);
        await openGroupAdjustOptionChain($);
        await tapFirstOptionChainStrikeCell($);

        await $.tester.tap(findAnyAdjustItemSellBtn());
        await $.pumpAndSettle();
        expect(findAnyAdjustItemDeleteBtn(), findsOneWidget);

        await $.tester.tap(findAnyAdjustItemBuyBtn());
        await $.pumpAndSettle();
        expect(findAnyAdjustItemDeleteBtn(), findsOneWidget);

        await tapOutsideModal($);
      },
    );

    patrolTest(
      'tapping the delete button removes the item from the adjust list',
      ($) async {
        await openChartWithMockPosition($);
        await openGroupAdjustOptionChain($);
        await tapFirstOptionChainStrikeCell($);
        expect(findAnyAdjustItemDeleteBtn(), findsOneWidget);

        await $.tester.tap(findAnyAdjustItemDeleteBtn());
        await $.pumpAndSettle();

        expect(findAnyAdjustItemDeleteBtn(), findsNothing);

        await tapOutsideModal($);
      },
    );
  });
}
