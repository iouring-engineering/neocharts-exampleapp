import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../../helpers.dart';
import '../positions_test_helpers.dart';
import 'group_adjust_test_helpers.dart';

// Group adjust's bottom action:
//   - Only rendered once the adjust list is non-empty -- hidden while just
//     the current position is shown.
//   - Cancel pops the option chain dialog without dispatching anything.
//   - Adjust Position dispatches the group-adjust submission then pops
//     immediately -- same fire-and-forget pattern as every other order/pad
//     in this app, so there is no in-dialog loading/success state to
//     assert here, only that the dialog closes the same way Cancel's does.
//
// Every test seeds a position, selects it, opens the option chain, and
// adds the first strike, so the bottom action is always present to act on.
// The "visibility" test below closes the option chain (tapOutsideModal)
// before finishing since it never taps Cancel/Adjust Position itself --
// see group_adjust_option_chain_test.dart's identical rationale.

void main() {
  group('Group adjust — bottom action visibility', () {
    patrolTest('the bottom action is hidden until an item is added to adjust', (
      $,
    ) async {
      await openChartWithMockPosition($);
      await openGroupAdjustOptionChain($);

      expect(find.byKey(Key(ChartTestKeys.groupAdjustSubmitBtn)), findsNothing);

      await tapFirstOptionChainStrikeCell($);

      expect(
        find.byKey(Key(ChartTestKeys.groupAdjustSubmitBtn)),
        findsOneWidget,
      );

      await tapOutsideModal($);
    });
  });

  group('Group adjust — bottom action submit and close', () {
    patrolTest('Cancel closes the option chain without adjusting', ($) async {
      await openChartWithMockPosition($);
      await openGroupAdjustOptionChain($);
      await tapFirstOptionChainStrikeCell($);

      await tapGroupAdjustCancel($);

      expect(find.byKey(Key(ChartTestKeys.groupAdjustCancelBtn)), findsNothing);
    });

    patrolTest('Adjust Position closes the option chain', ($) async {
      await openChartWithMockPosition($);
      await openGroupAdjustOptionChain($);
      await tapFirstOptionChainStrikeCell($);

      await tapGroupAdjustSubmit($);

      expect(find.byKey(Key(ChartTestKeys.groupAdjustSubmitBtn)), findsNothing);
    });
  });
}
