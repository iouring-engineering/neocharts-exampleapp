import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../helpers.dart';
import 'oco_test_helpers.dart';

// OCO modify flow (orders-list Modify action icon -> the OCO order pad
// with isModifyOCO: true):
//   - Both legs are always shown and pre-filled from the existing order;
//     their checkboxes are disabled (can't deselect a leg while modifying).
//   - The footer button reads "MODIFY" instead of "Apply".
//   - MODIFY dispatches the OCO modification and immediately closes the
//     pad; no loading/success state, same fire-and-forget pattern as
//     everywhere else in this app.
//
// Every test creates a fresh OCO order first (via the drag-to-create flow
// covered in oco_create_test.dart) so there is always exactly one to
// modify.

void main() {
  group('Orders — OCO modify', () {
    patrolTest(
      'modify pad opens with both legs pre-filled and a MODIFY button',
      ($) async {
        await openChartWithMockPosition($);
        await createOcoOrderViaDrag($, isSL: true);

        await openOrdersPanel($);
        await waitUntilPresent($, find.text('OCO'));
        await tapOcoModifyIcon($);

        expect(find.text('MODIFY'), findsOneWidget);
        expect(find.text('Set Stop Loss'), findsOneWidget);
        expect(find.text('Set Target Price'), findsOneWidget);
        expect(ocoLegFields('Set Stop Loss').first.controller.text, isNotEmpty);
        expect(
          ocoLegFields('Set Target Price').first.controller.text,
          isNotEmpty,
        );

        await $.tester.tap(find.text('Cancel'));
        await $.pumpAndSettle();
      },
    );

    patrolTest('submitting the pre-filled (valid) values closes the pad', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await createOcoOrderViaDrag($, isSL: true);

      await openOrdersPanel($);
      await waitUntilPresent($, find.text('OCO'));
      await tapOcoModifyIcon($);

      // Pre-filled values mirror the real order, so they're already
      // valid -- MODIFY should pass validation and pop without editing
      // anything.
      await $.tester.tap(find.text('MODIFY'));
      await $.pumpAndSettle();

      expect(find.text('MODIFY'), findsNothing);
    });

    patrolTest(
      'closing the modify pad by tapping Cancel leaves the order unchanged',
      ($) async {
        await openChartWithMockPosition($);
        await createOcoOrderViaDrag($, isSL: true);

        await openOrdersPanel($);
        await waitUntilPresent($, find.text('OCO'));
        await tapOcoModifyIcon($);

        await $.tester.tap(find.text('Cancel'));
        await $.pumpAndSettle();

        expect(find.text('MODIFY'), findsNothing);
        // The OCO order is still present and modifiable.
        expect(find.text('OCO'), findsOneWidget);
      },
    );
  });
}
