import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../helpers.dart';
import '../positions_test_helpers.dart';
import 'group_adjust_test_helpers.dart';

// Group adjust's option chain:
//   - Every cell in a strike/side row (including the leftmost strike-price
//     cell itself) shares the same tap handler -- in group-adjust mode it
//     toggles that strike's membership in the adjust list instead of
//     opening the normal order pad/chart-switch flow (which would pop this
//     dialog).
//   - The current (selected) position's own row and qty field are already
//     visible in the group-adjust panel docked under the chain, even
//     before anything is added to the adjust list.
//
// Every test opens the option chain from a freshly seeded, freshly
// selected position first, and closes it (tapOutsideModal) before
// finishing -- leaving the dialog open would race its own teardown against
// the next test's fresh pumpWidget().

void main() {
  group('Group adjust — option chain strike selection', () {
    patrolTest(
      'the current position is shown before anything is added to adjust',
      ($) async {
        await openChartWithMockPosition($);
        await openGroupAdjustOptionChain($);

        expect(find.text('Current Position'), findsOneWidget);
        expect(findCurrentPositionQtyField(), findsOneWidget);
        expect(findAnyAdjustItemDeleteBtn(), findsNothing);

        await tapOutsideModal($);
      },
    );

    patrolTest('tapping a strike cell adds it to the adjust list', ($) async {
      await openChartWithMockPosition($);
      await openGroupAdjustOptionChain($);

      await tapFirstOptionChainStrikeCell($);

      expect(findAnyAdjustItemDeleteBtn(), findsOneWidget);
      expect(findAnyAdjustItemQtyField(), findsOneWidget);
      expect(findAnyAdjustItemPriceField(), findsOneWidget);

      await tapOutsideModal($);
    });

    patrolTest(
      'tapping an already-added strike cell removes it from the adjust list',
      ($) async {
        await openChartWithMockPosition($);
        await openGroupAdjustOptionChain($);

        await tapFirstOptionChainStrikeCell($);
        expect(findAnyAdjustItemDeleteBtn(), findsOneWidget);

        await tapFirstOptionChainStrikeCell($);
        expect(findAnyAdjustItemDeleteBtn(), findsNothing);

        await tapOutsideModal($);
      },
    );
  });
}
