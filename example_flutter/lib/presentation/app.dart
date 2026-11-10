import 'package:material_ui/material_ui.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:neocharts_exampleapp/presentation/pages/home/home_page.dart';

class ChartTemplateApp extends StatefulWidget {
  const ChartTemplateApp({super.key, this.hostOverride, this.onInitDone});

  /// Test-only: substitutes the host this app would otherwise construct
  /// itself, so a test can hold a reference to seed data on it.
  final NeoChartsRepository? hostOverride;
  final void Function()? onInitDone;

  @override
  State<ChartTemplateApp> createState() => _ChartTemplateAppState();
}

class _ChartTemplateAppState extends State<ChartTemplateApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    // HomePage builds a host per chart open, so none is built here.
    widget.onInitDone?.call();
  }

  @override
  void dispose() {
    widget.hostOverride?.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chart Studio',
      themeMode: _themeMode,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090B10),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7CFF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),

      home: HomePage(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark,
        hostOverride: widget.hostOverride,
      ),
    );
  }
}
