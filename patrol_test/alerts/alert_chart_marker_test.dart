import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'alerts_test_helpers.dart';

// On-chart alert marker: a draggable, deletable price line drawn for every
// enabled, untriggered alert -- independent of the alerts-panel list already
// covered by modify_alert_test.dart / delete_alert_test.dart.
//   - Collapsed to a bell icon; tapping it reveals a drag handle, the
//     symbol's name badge, and a delete button.
//   - Dragging the handle opens the same create/modify dialog (in its
//     modify mode) the list's Modify icon opens, pre-filled with the
//     dropped (tick-snapped) price -- just a different entry point.
//   - The delete button fires the same delete action immediately, same as
//     the list's delete icon (no confirmation dialog either way).
//
// Every test creates a fresh alert via the panel first, then closes the
// panel (closeAlertsPanel) to reach the bare chart underneath, so there is
// always exactly one marker to act on.

void main() {
  group('Alerts — chart marker drag to modify', () {
    patrolTest('dragging the marker opens the modify dialog, pre-filled', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await createAlert($);
      await waitUntilPresent($, findAlertListItem());
      await closeAlertsPanel($);

      await dragAlertChartTag($);

      expect(find.text('Modify Alert'), findsOneWidget);

      await tapOutsideModal($);
    });

    patrolTest('submitting the dialog after a chart-marker drag closes it', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await createAlert($);
      await waitUntilPresent($, findAlertListItem());
      await closeAlertsPanel($);

      await dragAlertChartTag($);

      // The dropped price is already tick-snapped and nonzero, so this
      // passes validation without editing anything further.
      await tapAlertDialogSubmit($);

      expect(find.text('Modify Alert'), findsNothing);
    });

    patrolTest(
      'dismissing the dialog after a chart-marker drag leaves the alert unchanged',
      ($) async {
        await openChartAndAwaitLoad($);
        await createAlert($);
        await waitUntilPresent($, findAlertListItem());
        await closeAlertsPanel($);

        await dragAlertChartTag($);
        await tapOutsideModal($);

        expect(find.text('Modify Alert'), findsNothing);
        await openAlertsPanel($);
        expect(findAlertListItem(), findsWidgets);
      },
    );
  });

  group('Alerts — chart marker delete button', () {
    patrolTest(
      'tapping the on-chart delete button removes the alert and its marker',
      ($) async {
        await openChartAndAwaitLoad($);
        await createAlert($);
        await waitUntilPresent($, findAlertListItem());
        await closeAlertsPanel($);

        await deleteAlertViaChartTag($);

        await waitUntilAbsent(
          $,
          findAlertChartTag(),
          timeout: const Duration(seconds: 15),
        );
        expect(findAlertChartTag(), findsNothing);

        await openAlertsPanel($);
        expect(findAlertListItem(), findsNothing);
      },
    );
  });
}
