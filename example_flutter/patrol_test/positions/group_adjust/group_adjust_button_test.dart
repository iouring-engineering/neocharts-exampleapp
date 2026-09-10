import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import '../../helpers.dart';
import '../positions_test_helpers.dart';
import 'group_adjust_test_helpers.dart';

// Group adjust entry point:
//   - Hidden until at least one position is selected via its list checkbox
//     (and, in the real app, all selections sharing one underlying;
//     trivially satisfied here since the app only ever seeds one
//     position/underlying).
//   - The checkbox is a toggle: selecting then deselecting the same
//     position must hide the button again.
//
// Every test seeds a fresh position first so there is always exactly one
// to select.

void main() {
  group('Group adjust — entry button', () {
    patrolTest('the button is hidden until a position is selected', ($) async {
      await openChartWithMockPosition($);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());

      expect(find.byKey(Key(ChartTestKeys.groupAdjustBtn)), findsNothing);

      await tapPositionCheckbox($);

      expect(find.byKey(Key(ChartTestKeys.groupAdjustBtn)), findsOneWidget);
    });

    patrolTest('deselecting the position hides the button again', ($) async {
      await openChartWithMockPosition($);
      await openPositionsPanel($);
      await waitUntilPresent($, findPositionListItem());

      await tapPositionCheckbox($);
      expect(find.byKey(Key(ChartTestKeys.groupAdjustBtn)), findsOneWidget);

      await tapPositionCheckbox($);
      expect(find.byKey(Key(ChartTestKeys.groupAdjustBtn)), findsNothing);
    });
  });
}
