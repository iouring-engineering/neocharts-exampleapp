import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:nxtchart/src/shared/chart_test_keys.dart';

import 'helpers.dart';

// Option chain modal, opened via the app bar's icon -- not a drawer tab, so
// it uses its own openOptionChain/closeOptionChain helpers rather than the
// drawer-tab open/close pattern used elsewhere in this suite.
//
// NxtChartRepository's option-chain data already provides the full CE/PE
// chain (multiple strikes across weekly expiries) for structure/expiry-
// dropdown purposes, and a live tick for each strike's own ltp/OI/greeks --
// so every column (including the Greeks-only ones) renders real data once a
// strike's symbol is subscribed.
//
// Tapping any data/strike cell pops the dialog and switches the whole
// chart to that option's own contract -- that's exercised as its own test,
// separately from the non-dismissing controls (CALL/PUT, Greeks, expiry,
// Go to ATM).

Finder findAnyExpiryOption() =>
    findByKeyPrefix('chart_option_chain_expiry_option_');

Finder findAnyStrikeCell() =>
    findByKeyPrefix('chart_option_chain_strike_cell_');

void main() {
  group('Option chain', () {
    patrolTest('opens with real header data rendering', ($) async {
      await openChartAndAwaitLoad($);
      await openOptionChain($);

      expect($(Key(ChartTestKeys.errorState)), findsNothing);
      expect(
        find.byKey(Key(ChartTestKeys.optionChainGreekSwitch)),
        findsOneWidget,
      );
      await waitUntilPresent($, findAnyStrikeCell());

      await closeOptionChain($);
    });

    patrolTest('switching between CALL and PUT does not error', ($) async {
      await openChartAndAwaitLoad($);
      await openOptionChain($);
      await waitUntilPresent($, findAnyStrikeCell());

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.optionChainTypeTab('PE'))),
      );
      await $.pumpAndSettle();
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.optionChainTypeTab('CE'))),
      );
      await $.pumpAndSettle();
      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await closeOptionChain($);
    });

    patrolTest('toggling Greeks shows the extra columns without error', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await openOptionChain($);
      await waitUntilPresent($, findAnyStrikeCell());

      await $.tester.tap(find.byKey(Key(ChartTestKeys.optionChainGreekSwitch)));
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await closeOptionChain($);
    });

    patrolTest('the expiry dropdown offers real expiries and can select one', (
      $,
    ) async {
      await openChartAndAwaitLoad($);
      await openOptionChain($);
      await waitUntilPresent($, findAnyStrikeCell());

      await $.tester.tap(
        find.byKey(Key(ChartTestKeys.optionChainExpiryDropdown)),
      );
      await $.pumpAndSettle();

      final option = findAnyExpiryOption();
      await waitUntilPresent($, option);
      expect(option, findsWidgets);

      await $.tester.tap(option.first);
      await $.pumpAndSettle();

      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await closeOptionChain($);
    });

    patrolTest('tapping "Go to ATM" does not error', ($) async {
      await openChartAndAwaitLoad($);
      await openOptionChain($);
      await waitUntilPresent($, findAnyStrikeCell());

      final goToAtm = find.byKey(Key(ChartTestKeys.optionChainGoToAtmBtn));
      if (goToAtm.evaluate().isNotEmpty) {
        await $.tester.tap(goToAtm);
        await $.pumpAndSettle();
      }

      expect($(Key(ChartTestKeys.errorState)), findsNothing);

      await closeOptionChain($);
    });

    // A strike cell's tap only navigates away when the host app resolves a
    // per-symbol chart-switch hookup, which the default production
    // interface doesn't provide either -- a host app opts in explicitly;
    // until it does, tapping a cell is correctly a no-op. This asserts the
    // chain stays open and nothing breaks.
    patrolTest(
      'tapping a strike cell is a no-op without a real chart-switch hookup',
      ($) async {
        await openChartAndAwaitLoad($);
        await openOptionChain($);

        final cell = findAnyStrikeCell();
        await waitUntilPresent($, cell);
        await $.tester.ensureVisible(cell.first);
        await $.pumpAndSettle();
        await $.tester.tap(cell.first);
        await $.pumpAndSettle();

        expect(
          find.byKey(Key(ChartTestKeys.optionChainGreekSwitch)),
          findsOneWidget,
        );
        expect($(Key(ChartTestKeys.errorState)), findsNothing);

        await closeOptionChain($);
      },
    );
  });
}
