import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'alerts_test_helpers.dart';

// Delete alert flow (the alerts list's Delete icon):
//   - Unlike orders/OCO, there is no confirmation dialog at all -- tapping
//     the icon deletes the alert immediately.
//
// Every test creates a fresh alert first so there is always exactly one to
// delete.

void main() {
  group('Alerts — delete', () {
    patrolTest('tapping the delete icon removes the alert immediately', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await createAlert($);
      await waitUntilPresent($, findAlertListItem());

      await tapAlertDeleteIcon($);

      await waitUntilAbsent(
        $,
        findAlertListItem(),
        timeout: const Duration(seconds: 10),
      );
      expect(findAlertListItem(), findsNothing);
    });

    patrolTest(
      'the deletion persists after closing and reopening the alerts panel',
      ($) async {
        await openChartAndAwaitLoad($);
        await createAlert($);
        await waitUntilPresent($, findAlertListItem());

        await tapAlertDeleteIcon($);
        await waitUntilAbsent($, findAlertListItem());

        await closeAlertsPanel($);
        await openAlertsPanel($);

        expect(findAlertListItem(), findsNothing);
      },
    );
  });
}
