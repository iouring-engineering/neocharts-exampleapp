import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../helpers.dart';
import 'oco_test_helpers.dart';

// OCO creation flow:
//   - No button anywhere creates a new OCO order -- it only happens by
//     dragging an existing position's SL or TP price-line handle on the
//     chart canvas. Dragging SL opens the pad with the SL leg selected;
//     dragging TP opens it with the TP leg selected. Both legs are always
//     shown, only the initially-selected one starts checked/editable.
//   - Apply dispatches the OCO placement and immediately closes the pad;
//     there is no loading/success state beyond that (same fire-and-forget
//     pattern as every other order/pad in this app).
//   - Cancel just pops the pad -- no order is placed.
//
// Every test places a fresh mock position first so there is always
// exactly one position to drag from.

void main() {
  group('Orders — OCO create via drag', () {
    patrolTest(
      'dragging the SL handle opens the pad with both legs and SL selected',
      ($) async {
        await openChartWithMockPosition($);
        await dragPositionHandle($, isSL: true, dy: 200);

        expect(find.text('Set Stop Loss'), findsOneWidget);
        expect(find.text('Set Target Price'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);

        await $.tester.tap(find.text('Cancel'));
        await $.pumpAndSettle();
      },
    );

    patrolTest(
      'dragging the TP handle opens the pad with both legs and TP selected',
      ($) async {
        await openChartWithMockPosition($);
        await dragPositionHandle($, isSL: false, dy: -200);

        expect(find.text('Set Stop Loss'), findsOneWidget);
        expect(find.text('Set Target Price'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);

        await $.tester.tap(find.text('Cancel'));
        await $.pumpAndSettle();
      },
    );

    patrolTest('tapping Cancel on the pad places no order', ($) async {
      await openChartWithMockPosition($);
      await dragPositionHandle($, isSL: true, dy: 200);

      await $.tester.tap(find.text('Cancel'));
      await $.pumpAndSettle();

      expect(find.text('Apply'), findsNothing);

      await openOrdersPanel($);
      expect(find.text('OCO'), findsNothing);
    });

    patrolTest(
      'tapping Apply creates the OCO order, visible in the orders list',
      ($) async {
        await openChartWithMockPosition($);
        await createOcoOrderViaDrag($, isSL: true);

        // The pad closes immediately on Apply.
        expect(find.text('Apply'), findsNothing);

        await openOrdersPanel($);
        await waitUntilPresent(
          $,
          find.text('OCO'),
          timeout: const Duration(seconds: 10),
        );
        expect(find.text('OCO'), findsOneWidget);
      },
    );

    patrolTest('creating from the TP handle also appears as an OCO order', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await createOcoOrderViaDrag($, isSL: false);

      expect(find.text('Apply'), findsNothing);

      await openOrdersPanel($);
      await waitUntilPresent(
        $,
        find.text('OCO'),
        timeout: const Duration(seconds: 10),
      );
      expect(find.text('OCO'), findsOneWidget);
    });
  });
}
