import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/presentation/app.dart';
import 'package:nxtchart/interface.dart';
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
// page's "NEO Charts" card. [interfaceOverride], when supplied, replaces the
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
  await $.tester.ensureVisible(find.text('NEO Charts'));
  await $.tester.pumpAndSettle();
  await $('NEO Charts').tap();
  await $.pumpAndSettle();
  await waitUntilAbsent(
    $,
    find.byKey(Key(ChartTestKeys.loadingState)),
    timeout: const Duration(seconds: 30),
  );
}

// Taps the visual centre of the widget with key [key] -- needed for
// elements sitting inside an AnimatedPositioned/RepaintBoundary subtree that
// patrol's own hit-testable-visibility check treats as not visible even
// once genuinely on-screen (the hamburger toggle and drawer tabs).
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

// Opens the trading drawer (hamburger) then navigates to drawer tab [tab].
// [scrollTab] scrolls the tab into view first, needed for tabs that can sit
// past the visible fold in the drawer's tab strip.
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

// Closes drawer tab [tab]'s popup by tapping its own tab again, then
// collapses the tab strip so the next openDrawerTab call starts clean.
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

Future<void> openTopOptionsPanel(PatrolIntegrationTester $) =>
    openDrawerTab($, 'topFive', scrollTab: true);

Future<void> closeTopOptionsPanel(PatrolIntegrationTester $) =>
    closeDrawerTab($, 'topFive', scrollTab: true);
