import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'alerts_test_helpers.dart';

// Create alert flow:
//   - Opened from the alerts panel's "Create Alert" FAB; pre-fills the
//     trigger-price field from the chart's live LTP tick.
//   - Validation is just non-empty + parseable-as-double -- no
//     tick-size/LTP-boundary check at all, unlike orders/OCO.
//   - There's no separate Cancel button -- the dialog's barrier is
//     dismissible, same as everywhere else in this app.
//   - On Create: validation failure shows an inline error under the field
//     and leaves the dialog open; success creates the alert and pops
//     immediately.
//
// Every test opens a fresh chart first so there is never a pre-existing
// alert to interfere with tab/list assertions.

void main() {
  group('Alerts — create dialog', () {
    patrolTest('dialog opens with a pre-filled, non-empty price', ($) async {
      await openChartAndAwaitLoad($);
      await openCreateAlertDialog($);

      expect(find.text('Create Alert'), findsWidgets);
      expect(find.text('NIFTY 50'), findsWidgets);
      expect(
        $.tester
            .widget<TextField>(fieldByKey(ChartTestKeys.alertDialogValueField))
            .controller!
            .text,
        isNotEmpty,
      );

      await tapOutsideModal($);
    });

    patrolTest('tapping outside the dialog dismisses it without creating', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await openCreateAlertDialog($);

      await tapOutsideModal($);

      expect(find.text('LTP equals'), findsNothing);
    });
  });

  group('Alerts — create validation', () {
    patrolTest(
      'clearing the value and tapping Create shows a required-value error',
      ($) async {
        await openChartAndAwaitLoad($);
        await openCreateAlertDialog($);

        await setAlertValueField($, '');
        await tapAlertDialogSubmit($);

        await waitUntilPresent(
          $,
          find.text('Value cannot be empty'),
          timeout: const Duration(seconds: 5),
        );
        // Validation failure must not pop the dialog.
        expect(find.text('LTP equals'), findsOneWidget);

        await tapOutsideModal($);
      },
    );

    patrolTest('entering a non-numeric value shows an invalid-number error', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await openCreateAlertDialog($);

      await setAlertValueField($, 'abc');
      await tapAlertDialogSubmit($);

      await waitUntilPresent(
        $,
        find.text('Enter a valid number'),
        timeout: const Duration(seconds: 5),
      );
      expect(find.text('LTP equals'), findsOneWidget);

      await tapOutsideModal($);
    });
  });

  group('Alerts — create submit', () {
    patrolTest('submitting the pre-filled (valid) price creates the alert', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await createAlert($);

      expect(find.text('LTP equals'), findsNothing);
      await waitUntilPresent(
        $,
        findAlertListItem(),
        timeout: const Duration(seconds: 10),
      );
      expect(find.text('NIFTY 50'), findsWidgets);
    });

    patrolTest('a newly created alert appears under Active, not Triggered', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await createAlert($);
      await waitUntilPresent(
        $,
        findAlertListItem(),
        timeout: const Duration(seconds: 10),
      );

      await $.tester.tap(find.text('Triggered'));
      await $.pumpAndSettle();

      expect(findAlertListItem(), findsNothing);
    });
  });
}
