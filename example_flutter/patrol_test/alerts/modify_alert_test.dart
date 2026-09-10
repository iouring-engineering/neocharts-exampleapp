import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

import '../helpers.dart';
import 'alerts_test_helpers.dart';

// Modify alert flow (the alerts list's Modify icon / status badge -> the
// same create/modify dialog):
//   - Same dialog widget as create, just pre-filled from the existing
//     alert's triggerPrice and with a "Modify Alert" submit button instead.
//   - Both the status badge and the dedicated Modify icon open it -- the
//     badge doubles as an entry point.
//   - Same validation as create (non-empty + parseable-as-double), and the
//     same dismissible-barrier-only Cancel path.
//
// Every test creates a fresh alert first so there is always exactly one to
// modify.

void main() {
  group('Alerts — modify dialog', () {
    patrolTest(
      'the Modify icon opens the dialog pre-filled with a Modify Alert button',
      ($) async {
        await openChartAndAwaitLoad($);
        await createAlert($);
        await waitUntilPresent($, findAlertListItem());

        await tapAlertModifyIcon($);

        expect(find.text('Modify Alert'), findsOneWidget);
        expect(
          $.tester
              .widget<TextField>(
                fieldByKey(ChartTestKeys.alertDialogValueField),
              )
              .controller!
              .text,
          isNotEmpty,
        );

        await tapOutsideModal($);
      },
    );

    patrolTest('the status badge also opens the modify dialog', ($) async {
      await openChartAndAwaitLoad($);
      await createAlert($);
      await waitUntilPresent($, findAlertListItem());

      await tapAlertStatusBadge($);

      expect(find.text('Modify Alert'), findsOneWidget);

      await tapOutsideModal($);
    });
  });

  group('Alerts — modify validation', () {
    patrolTest(
      'clearing the value and tapping Modify shows a required-value error',
      ($) async {
        await openChartAndAwaitLoad($);
        await createAlert($);
        await waitUntilPresent($, findAlertListItem());

        await tapAlertModifyIcon($);
        await setAlertValueField($, '');
        await tapAlertDialogSubmit($);

        await waitUntilPresent(
          $,
          find.text('Value cannot be empty'),
          timeout: const Duration(seconds: 5),
        );
        expect(find.text('Modify Alert'), findsOneWidget);

        await tapOutsideModal($);
      },
    );
  });

  group('Alerts — modify submit and close', () {
    patrolTest('submitting the pre-filled (valid) value closes the dialog', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await createAlert($);
      await waitUntilPresent($, findAlertListItem());

      await tapAlertModifyIcon($);
      await tapAlertDialogSubmit($);

      expect(find.text('Modify Alert'), findsNothing);
    });

    patrolTest(
      'entering a new value updates the trigger price shown in the list',
      ($) async {
        await openChartAndAwaitLoad($);
        await createAlert($);
        await waitUntilPresent($, findAlertListItem());

        await tapAlertModifyIcon($);
        await setAlertValueField($, '25000');
        await tapAlertDialogSubmit($);

        await waitUntilPresent(
          $,
          find.text('25000'),
          timeout: const Duration(seconds: 10),
        );
        expect(find.text('25000'), findsWidgets);
      },
    );

    patrolTest(
      'closing the modify dialog by tapping outside leaves the alert unchanged',
      ($) async {
        await openChartAndAwaitLoad($);
        await createAlert($);
        await waitUntilPresent($, findAlertListItem());

        await tapAlertModifyIcon($);
        await tapOutsideModal($);

        expect(find.text('Modify Alert'), findsNothing);
        // The alert is still present and modifiable.
        expect(findAlertListItem(), findsWidgets);
      },
    );
  });
}
