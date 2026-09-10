import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../helpers.dart';
import 'oco_test_helpers.dart';

// OCO cancel flow (orders-list close action icon -> the same cancel
// confirmation dialog used for plain orders, with isOCO: true):
//   - Same widget as the plain-order cancel confirmation, just with the
//     OCO branch: header/confirm button read "Cancel OCO" instead of
//     "Cancel Order", body text is OCO-specific, and confirming cancels
//     the whole linked group instead of a single order.
//   - "Keep Order" dismisses without cancelling, same as plain orders.
//
// Every test creates a fresh OCO order first (via the drag-to-create flow
// covered in oco_create_test.dart) so there is always exactly one to
// cancel.

void main() {
  group('Orders — OCO cancel', () {
    patrolTest('cancel dialog shows the OCO-specific confirmation prompt', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await createOcoOrderViaDrag($, isSL: true);

      await openOrdersPanel($);
      await waitUntilPresent($, find.text('OCO'));
      await tapOcoCancelIcon($);

      expect(find.text('Cancel OCO'), findsWidgets);
      expect(
        find.text('Are you sure you want to cancel this OCO order?'),
        findsOneWidget,
      );
    });

    patrolTest('"Keep Order" dismisses the dialog without cancelling', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await createOcoOrderViaDrag($, isSL: true);

      await openOrdersPanel($);
      await waitUntilPresent($, find.text('OCO'));
      await tapOcoCancelIcon($);

      await $.tester.tap(find.text('Keep Order'));
      await $.pumpAndSettle();

      expect(
        find.text('Are you sure you want to cancel this OCO order?'),
        findsNothing,
      );
      expect(find.text('OCO'), findsOneWidget);
    });

    patrolTest(
      'confirming cancellation removes the OCO order from the open list',
      ($) async {
        await openChartWithMockPosition($);
        await createOcoOrderViaDrag($, isSL: true);

        await openOrdersPanel($);
        await waitUntilPresent($, find.text('OCO'));
        await tapOcoCancelIcon($);

        // Header and confirm button share the same "Cancel OCO" label --
        // the confirm button is the last match, matching the dialog's
        // bottom-action position (same convention as the plain-order
        // cancel test).
        await $.tester.tap(find.text('Cancel OCO').last);
        await $.pumpAndSettle();

        await waitUntilAbsent(
          $,
          find.text('OCO'),
          timeout: const Duration(seconds: 15),
        );
        expect(find.text('OCO'), findsNothing);
      },
    );
  });
}
