import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

// Shared drag helper for the feature performance suites (alerts, positions,
// orders, search). All four open a drawer panel / bottom sheet whose list
// isn't virtualized (every row stays mounted once built, just scrolled
// off-screen), so a raw screen-coordinate drag is used instead of dragging
// a specific row's finder -- mirrors benchmark_perf_test.dart's own option
// chain / indicator browser scroll tests, which document the same
// reasoning.
Future<void> dragListUp(
  PatrolIntegrationTester $, {
  int times = 10,
  double dy = 200,
}) async {
  final view = $.tester.view;
  final screenSize = view.physicalSize / view.devicePixelRatio;
  final dragStart = Offset(screenSize.width / 2, screenSize.height / 2);

  for (var i = 0; i < times; i++) {
    await $.tester.dragFrom(dragStart, Offset(0, -dy));
    await $.tester.pump(const Duration(milliseconds: 16));
  }
}
