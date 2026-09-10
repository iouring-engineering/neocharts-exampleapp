import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'positions_test_helpers.dart';

// On-chart position marker: dragging its SL/TP handle is the *only* way to
// create an OCO order in this app -- the positions feature owns this entry
// point even though the order it creates lives in the orders/OCO domain.
//
// This file only proves the drag interaction is reachable and does what
// it's supposed to (open the OCO pad, pre-filled from the dropped price).
// The full OCO create/modify/cancel lifecycle -- validation, Apply/Cancel,
// the resulting order's shape -- is already exhaustively covered in
// orders/oco/oco_create_test.dart and its siblings; duplicating that here
// would just be the same assertions under a different file name.
//
// Every test seeds a fresh position first so there is always exactly one
// to drag.

void main() {
  group('Positions — chart marker SL-TP drag', () {
    patrolTest('dragging the SL handle opens the OCO pad', ($) async {
      await openChartWithMockPosition($);
      await dragPositionHandle($, isSL: true);

      expect(find.text('Set Stop Loss'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      await $.tester.tap(find.text('Cancel'));
      await $.pumpAndSettle();
    });

    patrolTest('dragging the TP handle opens the OCO pad', ($) async {
      await openChartWithMockPosition($);
      await dragPositionHandle($, isSL: false);

      expect(find.text('Set Target Price'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      await $.tester.tap(find.text('Cancel'));
      await $.pumpAndSettle();
    });
  });
}
