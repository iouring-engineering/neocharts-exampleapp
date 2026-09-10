import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'positions_test_helpers.dart';

// Normal (single-position) adjust flow -- explicitly excludes group_adjust,
// a separate multi-position, option-chain-driven flow covered under
// group_adjust/.
//   - Opened from an open position's Adjust icon.
//   - Fetches a real option chain for the position's underlying, which
//     populates the "adjust to" expiry/strike pickers; the rest of the
//     panel (current-position quantity, order-type toggle, price field,
//     Cancel/Adjust buttons) renders and behaves the same regardless of
//     what that chain contains.
//   - Validation checks *two* quantity fields independently: the current
//     position's own lot count (ChartTestKeys.adjustPositionQtyField) and
//     the adjust-to lot count (ChartTestKeys.adjustToQtyField).
//   - On the default order type (Market), price is never checked, so the
//     pre-filled (valid) quantities submit successfully as-is.
//
// Every test seeds a fresh position first so there is always exactly one
// to adjust.

void main() {
  group('Positions — adjust dialog', () {
    patrolTest(
      'panel opens with a pre-filled quantity on the current position',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionAdjustIcon($);

        expect(find.text('Adjust Position'), findsWidgets);
        expect(find.text('Current Position'), findsOneWidget);
        expect(
          $.tester
              .widget<TextField>(
                fieldByKey(ChartTestKeys.adjustPositionQtyField),
              )
              .controller!
              .text,
          isNotEmpty,
        );

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.adjustPositionCancelBtn)),
        );
        await $.pumpAndSettle();
      },
    );
  });

  group('Positions — adjust validation', () {
    patrolTest(
      'clearing the current-position quantity shows a required-quantity error',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionAdjustIcon($);

        await clearField($, fieldByKey(ChartTestKeys.adjustPositionQtyField));
        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.adjustPositionSubmitBtn)),
        );
        await $.pumpAndSettle();

        await waitUntilPresent(
          $,
          find.text('Please enter the quantity'),
          timeout: const Duration(seconds: 5),
        );
        expect(find.text('Current Position'), findsOneWidget);

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.adjustPositionCancelBtn)),
        );
        await $.pumpAndSettle();
      },
    );

    patrolTest(
      'clearing the adjust-to quantity shows a required-quantity error',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionAdjustIcon($);

        await clearField($, fieldByKey(ChartTestKeys.adjustToQtyField));
        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.adjustPositionSubmitBtn)),
        );
        await $.pumpAndSettle();

        await waitUntilPresent(
          $,
          find.text('Please enter the quantity'),
          timeout: const Duration(seconds: 5),
        );
        expect(find.text('Current Position'), findsOneWidget);

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.adjustPositionCancelBtn)),
        );
        await $.pumpAndSettle();
      },
    );
  });

  group('Positions — adjust submit and close', () {
    patrolTest(
      'submitting the pre-filled (valid) quantities closes the panel',
      ($) async {
        await openChartWithMockPosition($);
        await openPositionsPanel($);
        await waitUntilPresent($, findPositionListItem());
        await tapPositionAdjustIcon($);

        await $.tester.tap(
          find.byKey(Key(ChartTestKeys.adjustPositionSubmitBtn)),
        );
        await $.pumpAndSettle();

        expect(find.text('Current Position'), findsNothing);
      },
    );

    patrolTest('tapping Cancel closes the panel without adjusting', ($) async {
      await openChartWithMockPosition($);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());
      await tapPositionAdjustIcon($);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.adjustPositionCancelBtn)),
      );
      await $.pumpAndSettle();

      expect(find.text('Current Position'), findsNothing);
      // The position is still present and adjustable.
      expect(findPositionListItem(), findsOneWidget);
    });
  });
}
