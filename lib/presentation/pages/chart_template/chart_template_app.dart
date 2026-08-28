import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/presentation/pages/charts/nxt_chart_screen.dart';
import 'package:neocharts_exampleapp/presentation/pages/charts/nxt_scalper_chart_screen.dart';

class ChartTemplateApp extends StatefulWidget {
  const ChartTemplateApp({super.key});

  @override
  State<ChartTemplateApp> createState() => _ChartTemplateAppState();
}

class _ChartTemplateAppState extends State<ChartTemplateApp> {
  ThemeMode _themeMode = ThemeMode.dark;

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
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─────────────────────────────
                        // TOP BAR
                        // ─────────────────────────────
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7C5CFF),
                                    Color(0xFF4B8BFF),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.candlestick_chart_rounded,
                                color: Colors.white,
                                size: 25,
                              ),
                            ),

                            const SizedBox(width: 14),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NeoCharts',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Trading intelligence',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // Theme Button
                            Material(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                onTap: onToggleTheme,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: Icon(
                                      isDarkMode
                                          ? Icons.light_mode_rounded
                                          : Icons.dark_mode_rounded,
                                      key: ValueKey(isDarkMode),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 70),

                        // ─────────────────────────────
                        // HERO
                        // ─────────────────────────────
                        Text(
                          'Choose your\nchart workspace.',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -1.5,
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'Explore powerful charting tools designed for '
                          'analysis, strategy and precision trading.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: theme.textTheme.bodyLarge?.color?.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),

                        const SizedBox(height: 44),

                        // ─────────────────────────────
                        // CHART BUTTONS
                        // ─────────────────────────────
                        Column(
                          children: [
                            ChartCard(
                              title: 'Scalper Charts',
                              subtitle: 'Fast charts for precision entries',
                              icon: Icons.show_chart_rounded,
                              gradient: const [
                                Color(0xFF00A884),
                                Color(0xFF00C6A2),
                              ],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NxtScalperChartScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            ChartCard(
                              title: 'Single Chart',
                              subtitle: 'Advanced market visualization',
                              icon: Icons.auto_graph_rounded,
                              gradient: const [
                                Color(0xFF7657FF),
                                Color(0xFF4D8DFF),
                              ],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NxtChartScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 60),

                        // ─────────────────────────────
                        // FOOTER
                        // ─────────────────────────────
                        Center(
                          child: Text(
                            'BUILT BY IOURING',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.labelSmall?.color
                                  ?.withValues(alpha: 0.35),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ChartCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const ChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              height: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.gradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradient.first.withValues(alpha: 0.20),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 45,
                    bottom: -80,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          widget.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 7),

                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Text(
                              'Open workspace',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
