import 'dart:async';

import 'package:financial_chart/financial_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/presentation/app.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/src/presentation/blocs/chart_bloc.dart';
import 'package:nxtchart/src/shared/chart_test_keys.dart';
import 'package:patrol/patrol.dart';

// Polls until [finder] finds no widgets, or [timeout] elapses.
// patrol 3.x/4.x has no built-in "waitUntilGone"; this fills that gap.
Future<void> waitUntilAbsent(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out waiting for '
        '${finder.describeMatch(Plurality.one)} to disappear.',
      );
    }
    await $.tester.pump(interval);
  }
  await $.pumpAndSettle();
}

// Pumps [ChartTemplateApp], waits for initialization, and taps the home
// page's "NeoCharts" card. [interfaceOverride], when supplied, replaces the
// ChartInterface the app would otherwise construct itself -- e.g. a handle
// to seed positions on via seedPosition().
Future<void> openChartAndAwaitLoad(
  PatrolIntegrationTester $, {
  ChartInterface? interfaceOverride,
}) async {
  final completer = Completer<void>();
  await $.pumpWidget(
    ChartTemplateApp(
      interfaceOverride: interfaceOverride,
      onInitDone: completer.complete,
      onInitError: completer.completeError,
    ),
  );
  await completer.future;
  await $.tester.pump(const Duration(milliseconds: 300));
  await $.tester.ensureVisible(find.text('NeoCharts'));
  await $.tester.pumpAndSettle();
  await $('NeoCharts').tap();
  await $.pumpAndSettle();
  await waitUntilAbsent(
    $,
    find.byKey(Key(ChartTestKeys.loadingState)),
    timeout: const Duration(seconds: 30),
  );
}

// Closes the chart (via the app bar's own close button) and re-opens a
// fresh instance from the same home page, reusing the same underlying
// ChartInterface/SharedPreferences. Used to prove a saved order preference
// is genuinely read back from persisted storage on a fresh screen, not just
// carried over via in-memory bloc state.
Future<void> closeAndReopenChart(PatrolIntegrationTester $) async {
  final closeBtn = find.byKey(Key(ChartTestKeys.closeBtn));
  await waitUntilPresent($, closeBtn, timeout: const Duration(seconds: 30));
  await $.tester.tap(closeBtn);
  await $.pumpAndSettle();
  await $('NeoCharts').tap();
  await $.pumpAndSettle();
  await waitUntilAbsent(
    $,
    find.byKey(Key(ChartTestKeys.loadingState)),
    timeout: const Duration(seconds: 30),
  );
}

// Opens the chart menu's Order Preferences tab.
Future<void> openOrderPrefsMenu(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.menuToggleBtn)).first);
  await $.pumpAndSettle();
  await $.tester.tap(find.byKey(Key(ChartTestKeys.menuRailOrderPrefs)));
  await $.pumpAndSettle();
}

// Closes the chart menu opened by openOrderPrefsMenu (toggle off). Waits
// for the popup's own content to actually leave the tree rather than
// trusting pumpAndSettle alone -- the live streaming data keeps scheduling
// new frames, which can make pumpAndSettle return before a short close
// animation truly finishes.
Future<void> closeOrderPrefsMenu(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.menuToggleBtn)).first);
  await $.pumpAndSettle();
  await waitUntilAbsent($, find.byKey(Key(ChartTestKeys.menuRailOrderPrefs)));
}

// Switches the Order Preferences view's own TabBar to the tab named
// [name] -- 'oneTap' or 'indices' (OrderPreferenceTypes.name values).
Future<void> switchOrderPrefsTab(PatrolIntegrationTester $, String name) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.orderPrefsTab(name))));
  await $.pumpAndSettle();
}

// Taps [side]'s strike-type dropdown on the Index tab and selects [label]
// ('ITM'/'ATM'/'OTM' -- StrikeType.label values).
Future<void> setOrderPrefsStrikeType(
  PatrolIntegrationTester $, {
  required String side,
  required String label,
}) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.orderPrefsStrikeTypeDropdown(side))),
  );
  await $.pumpAndSettle();
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.orderPrefsStrikeTypeOption(side, label))),
  );
  await $.pumpAndSettle();
}

// Taps [side]'s offset stepper's increment button [times] times.
Future<void> incrementOrderPrefsOffset(
  PatrolIntegrationTester $, {
  required String side,
  int times = 1,
}) async {
  final btn = find.byKey(Key(ChartTestKeys.orderPrefsOffsetIncrementBtn(side)));
  for (var i = 0; i < times; i++) {
    await $.tester.tap(btn);
    await $.pumpAndSettle();
  }
}

// Taps [side]'s lots stepper's increment button [times] times.
Future<void> incrementOrderPrefsLots(
  PatrolIntegrationTester $, {
  required String side,
  int times = 1,
}) async {
  final btn = find.byKey(Key(ChartTestKeys.orderPrefsLotsIncrementBtn(side)));
  for (var i = 0; i < times; i++) {
    await $.tester.tap(btn);
    await $.pumpAndSettle();
  }
}

// Taps the Index tab's Apply button, dispatching SetOrderPreference and
// persisting the currently-selected index/strike-type/offset/lots via
// real SharedPreferences, not mocked.
Future<void> applyOrderPrefs(PatrolIntegrationTester $, String tabName) async {
  await $.tester.tap(
    find.byKey(Key(ChartTestKeys.orderPrefsApplyBtn(tabName))),
  );
  await $.pumpAndSettle();
}

// Opens the chart menu and navigates to the intervals / ranges tab.
Future<void> openIntervalMenu(PatrolIntegrationTester $) async {
  await $(Key(ChartTestKeys.menuToggleBtn)).tap();
  await $.pumpAndSettle();
  await $(Key(ChartTestKeys.menuRailIntervals)).tap();
  await $.pumpAndSettle();
}

// Scrolls the interval chip list until [name] is visible, then taps it.
// Required because chips below the fold are in the tree but not hit-testable
// and patrol's tap() does not auto-scroll SingleChildScrollView.
Future<void> tapIntervalChip(PatrolIntegrationTester $, String name) async {
  final chip = $(Key(ChartTestKeys.intervalChip(name)));
  await $.scrollUntilVisible(
    finder: chip,
    view: find.byKey(Key(ChartTestKeys.intervalChipList)),
    delta: 80,
    maxScrolls: 20,
  );
  await chip.tap();
}

// Taps the widget keyed [key] directly via its RenderBox, bypassing
// patrol's own hit-testable-visibility check -- both the hamburger toggle
// and the drawer's tab items sit inside an animated/repaint-boundary
// subtree that patrol's finder treats as not visible even once it's
// genuinely on-screen.
//
// [localPoint] overrides the default (the box's own centre) -- needed for
// the hamburger toggle specifically: its tap target stretches to the
// drawer's full width, but in portrait only the ~50px-wide icon at the
// left edge actually paints, so the box's arithmetic centre lands on empty
// space that falls through to the chart canvas underneath.
Future<void> tapByKeyCentre(
  PatrolIntegrationTester $,
  String key, {
  Offset? localPoint,
}) async {
  final finder = find.byKey(Key(key));
  final box = finder.evaluate().first.renderObject! as RenderBox;
  final point = localPoint ?? Offset(box.size.width / 2, box.size.height / 2);
  await $.tester.tapAt(box.localToGlobal(point));
}

Future<void> _tapHamburger(PatrolIntegrationTester $) async {
  await tapByKeyCentre(
    $,
    ChartTestKeys.hamburgerBtn,
    localPoint: const Offset(25, 15),
  );
  await $.pumpAndSettle();
}

// Opens the trading drawer (hamburger) then navigates to drawer tab [tab]
// ('orders'/'positions'/'topFive'/'pl'/'alerts'/'analysis'). [scrollTab]
// scrolls the tab into view first -- needed for tabs that can sit past the
// visible fold in the drawer's own tab strip ('topFive', 'pl', 'analysis');
// 'orders'/'positions'/'alerts' sit near the top and never need it.
Future<void> openDrawerTab(
  PatrolIntegrationTester $,
  String tab, {
  bool scrollTab = false,
}) async {
  await _tapHamburger($);
  final tabFinder = find.byKey(Key(ChartTestKeys.drawerTab(tab)));
  if (scrollTab) {
    await $.tester.ensureVisible(tabFinder);
    await $.pumpAndSettle();
  }
  await tapByKeyCentre($, ChartTestKeys.drawerTab(tab));
  await $.pumpAndSettle();
}

// Closes drawer tab [tab]'s popup by tapping its own tab again -- the
// already-active tab toggles its popup closed when tapped a second time
// (used by every tab here that has no dedicated close button of its own)
// -- then collapses the tab strip, since every openDrawerTab call above
// assumes that strip starts closed; leaving it open would make the next
// one's hamburger tap close it instead of opening the tab it actually
// wants. [scrollTab] mirrors openDrawerTab.
Future<void> closeDrawerTab(
  PatrolIntegrationTester $,
  String tab, {
  bool scrollTab = false,
}) async {
  if (scrollTab) {
    await $.tester.ensureVisible(find.byKey(Key(ChartTestKeys.drawerTab(tab))));
    await $.pumpAndSettle();
  }
  await tapByKeyCentre($, ChartTestKeys.drawerTab(tab));
  await $.pumpAndSettle();
  await _tapHamburger($);
}

Future<void> openOrdersPanel(PatrolIntegrationTester $) =>
    openDrawerTab($, 'orders');

Future<void> openPositionsPanel(PatrolIntegrationTester $) =>
    openDrawerTab($, 'positions');

Future<void> closePositionsPanel(PatrolIntegrationTester $) =>
    closeDrawerTab($, 'positions');

Future<void> openTopOptionsPanel(PatrolIntegrationTester $) =>
    openDrawerTab($, 'topFive', scrollTab: true);

Future<void> closeTopOptionsPanel(PatrolIntegrationTester $) =>
    closeDrawerTab($, 'topFive', scrollTab: true);

Future<void> openPlPanel(PatrolIntegrationTester $) =>
    openDrawerTab($, 'pl', scrollTab: true);

Future<void> closePlPanel(PatrolIntegrationTester $) =>
    closeDrawerTab($, 'pl', scrollTab: true);

Future<void> openAlertsPanel(PatrolIntegrationTester $) =>
    openDrawerTab($, 'alerts');

Future<void> closeAlertsPanel(PatrolIntegrationTester $) =>
    closeDrawerTab($, 'alerts');

Future<void> openAnalysisPanel(PatrolIntegrationTester $) =>
    openDrawerTab($, 'analysis', scrollTab: true);

// The analysis panel has its own dedicated close button (unlike
// topFive/pl, whose closeXPanel just re-taps the drawer tab), so this
// doesn't go through closeDrawerTab -- it still collapses the tab strip
// afterwards for the same reason closeDrawerTab does.
Future<void> closeAnalysisPanel(PatrolIntegrationTester $) async {
  await $.tester.tap(find.byKey(Key(ChartTestKeys.analysisCloseBtn)));
  await $.pumpAndSettle();
  await _tapHamburger($);
}

// Opens the option chain modal via the symbol title's tap target -- the
// dedicated app-bar icon only renders in one orientation state, while the
// title tap is the one entry point guaranteed to exist regardless.
Future<void> openOptionChain(PatrolIntegrationTester $) async {
  // A short warm-up settle -- opening the option chain immediately after
  // the chart's very first frame can catch its custom font metrics mid-
  // load, which briefly widens the CALL/PUT toggle's text just enough to
  // overflow its row (self-heals after this point; never reproduces once
  // the app has rendered a few real frames).
  await $.tester.pump(const Duration(milliseconds: 500));
  await $.pumpAndSettle();
  await $.tester.tap(find.byKey(Key(ChartTestKeys.chartTitleSymbolBtn)));
  await $.pumpAndSettle();
}

// Dismisses the option chain's modal via tapOutsideModal below -- the
// dialog is centred, so a screen corner always lands outside it.
Future<void> closeOptionChain(PatrolIntegrationTester $) => tapOutsideModal($);

// Taps the centre of the chart canvas to open the order pad.
// Retries until the order pad buy button appears (the viewport may need
// an extra frame to finish layout after the loading state clears). The
// chart canvas itself is rendered by a custom-painted surface that can't
// carry a Flutter Key, so this taps the logical screen centre instead,
// which sits well inside the chart canvas below the app bar for any real
// device size.
Future<void> openOrderPad(
  PatrolIntegrationTester $, {
  int maxAttempts = 5,
}) async {
  final view = $.tester.view;
  final screenSize = view.physicalSize / view.devicePixelRatio;
  final centre = Offset(screenSize.width / 2, screenSize.height / 2);
  for (var i = 0; i < maxAttempts; i++) {
    await $.tester.pump(const Duration(milliseconds: 300));
    await $.tester.tapAt(centre);
    await $.tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(Key(ChartTestKeys.orderPadBuyBtn)).evaluate().isNotEmpty) {
      return;
    }
  }
  // Final settle — let the pad finish animating in.
  await $.pumpAndSettle();
}

// Finds every widget whose key is a ValueKey<String> starting with
// [prefix] -- for keys built from a dynamic id (order/position/alert ids,
// option-chain strike ids) where there's no fixed literal to key an exact
// widget off. Shared by every suite's findAnyXxx-style finders below.
Finder findByKeyPrefix(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(prefix),
);

// Finds the first open-order cancel button in the orders list.
// Returns null if no such button is currently rendered.
Finder findAnyOrderCancelBtn() => findByKeyPrefix('chart_order_list_cancel_');

// Finds the first open-order modify button in the orders list.
Finder findAnyOrderModifyBtn() => findByKeyPrefix('chart_order_list_modify_');

// Dismisses a modal bottom sheet or dialog by tapping its barrier (outside
// the sheet/dialog content) instead of any action button. Both default to
// dismissible barriers, and their content is anchored (bottom sheet:
// bottom-aligned; dialog: centred), so a screen corner always lands
// outside it.
Future<void> tapOutsideModal(PatrolIntegrationTester $) async {
  await $.tester.tapAt(const Offset(10, 10));
  await $.pumpAndSettle();
}

// The [key]-keyed field's own inner TextField -- both wrap their field in
// a key on the outer widget, so this walks down to the real TextField for
// reading/setting .text.
Finder fieldByKey(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

// Clears a text field's value by setting its controller directly rather
// than simulating text input. The stepper/text field goes read-only at
// the platform-input level whenever an ambient numeric keypad scope is
// active -- WidgetTester.enterText silently no-ops on it there.
Future<void> clearField(PatrolIntegrationTester $, Finder finder) async {
  $.tester.widget<TextField>(finder).controller!.text = '';
  await $.pumpAndSettle();
}

// Sets a text field's value directly, same rationale as [clearField].
Future<void> setField(
  PatrolIntegrationTester $,
  Finder finder,
  String value,
) async {
  $.tester.widget<TextField>(finder).controller!.text = value;
  await $.pumpAndSettle();
}

// Waits until at least one widget matching [finder] is present.
Future<void> waitUntilPresent(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  Duration interval = const Duration(milliseconds: 200),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Timed out waiting for '
        '${finder.describeMatch(Plurality.one)} to appear.',
      );
    }
    await $.tester.pump(interval);
  }
}

// Closes the chart menu (toggle off).
Future<void> closeMenu(PatrolIntegrationTester $) async {
  await $(Key(ChartTestKeys.menuToggleBtn)).tap();
  await $.pumpAndSettle();
}

// Opens the chart menu and navigates to the indicators browser tab.
Future<void> openIndicatorMenu(PatrolIntegrationTester $) async {
  await $(Key(ChartTestKeys.menuToggleBtn)).tap();
  await $.pumpAndSettle();
  await $(Key(ChartTestKeys.menuRailIndicators)).tap();
  await $.pumpAndSettle();
}

// Waits for any in-progress data reload banner to clear, then settles.
Future<void> awaitDataReload(PatrolIntegrationTester $) async {
  await waitUntilAbsent(
    $,
    find.byKey(Key(ChartTestKeys.dataLoadingState)),
    timeout: const Duration(seconds: 15),
  );
}

// Opens the chart menu and navigates to the chart types tab.
Future<void> openChartTypeMenu(PatrolIntegrationTester $) async {
  await $(Key(ChartTestKeys.menuToggleBtn)).tap();
  await $.pumpAndSettle();
  await $(Key(ChartTestKeys.menuRailChartTypes)).tap();
  await $.pumpAndSettle();
}

// Taps the chart type row for [name] (a ChartType enum value name).
// Scrolls the row into view first: the list lives in an unbounded
// scroll view with no dedicated list key to scroll against, and patrol's
// tap() does not auto-scroll one -- a narrower popup layout can leave
// later rows (e.g. Volume Candle, the last entry) below the fold.
Future<void> tapChartTypeRow(PatrolIntegrationTester $, String name) async {
  final row = $(Key(ChartTestKeys.chartTypeRow(name)));
  await $.tester.ensureVisible(row);
  await $.pumpAndSettle();
  await row.tap();
}

// Opens the chart menu and navigates to the layout tab, then selects
// [layoutName] (a ChartLayout enum value name: 'singleChart',
// 'indexCallPut', or 'callPut'). indexCallPut/callPut only render once
// selected here -- the current app always starts on singleChart.
Future<void> selectChartLayout(
  PatrolIntegrationTester $,
  String layoutName,
) async {
  await $(Key(ChartTestKeys.menuToggleBtn)).tap();
  await $.pumpAndSettle();
  await $(Key(ChartTestKeys.menuRailLayout)).tap();
  await $.pumpAndSettle();
  final row = $(Key(ChartTestKeys.layoutRow(layoutName)));
  await $.tester.ensureVisible(row);
  await $.pumpAndSettle();
  await row.tap();
  await $.pumpAndSettle();
  await closeMenu($);
}

// Opens the chart-type menu for the RIGHT-hand panel of a dual-panel
// layout (indexCallPut/callPut, selected via [selectChartLayout] first).
// A dual-panel layout mounts two independent chart panels, each with its
// own menu toggle, so `menuToggleBtn` matches two widgets: index 0 is the
// left panel's toggle, index 1 is the right panel's.
Future<void> openChartTypeMenuRightPanel(PatrolIntegrationTester $) async {
  await $(Key(ChartTestKeys.menuToggleBtn)).at(1).tap();
  await $.pumpAndSettle();
  await $(Key(ChartTestKeys.menuRailChartTypes)).tap();
  await $.pumpAndSettle();
}

// Closes the right-hand panel's menu opened by [openChartTypeMenuRightPanel].
// The popup renders its own full-screen barrier above everything else while
// open -- including the toggle button that opened it, so re-tapping the
// toggle by key fails. Tapping the barrier itself (any point outside the
// popup panel, which occupies only part of the screen width) is what
// actually closes it.
Future<void> closeChartTypeMenuRightPanel(PatrolIntegrationTester $) async {
  await $.tester.tapAt(const Offset(10, 10));
  await $.pumpAndSettle();
}

// Returns the dual-panel layout's RIGHT-hand panel's live `GChart` -- the
// same object the chart bloc mutates on a chart-type change -- so a test
// can verify the actual rendered graph, not just the picker's selection.
GChart currentChartRightPanel(PatrolIntegrationTester $) {
  final overlayElement = $.tester.element(
    find.byKey(Key(ChartTestKeys.debugVisibleRange)).last,
  );
  return BlocProvider.of<ChartBloc>(overlayElement).state.chart!;
}
