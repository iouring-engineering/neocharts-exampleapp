import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neocharts_exampleapp/presentation/app.dart';

void main() {
  testWidgets('Home page shows the chart workspace options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChartTemplateApp());
    await tester.pump();

    expect(find.text('NeoCharts'), findsOneWidget);
    expect(find.text('Scalper Charts'), findsOneWidget);
    expect(find.text('Single Chart'), findsOneWidget);
  });

  testWidgets('Theme toggle switches between light and dark', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChartTemplateApp());
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    await tester.tap(find.byIcon(Icons.light_mode_rounded));
    await tester.pump();

    final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(updatedApp.themeMode, ThemeMode.light);
  });
}
