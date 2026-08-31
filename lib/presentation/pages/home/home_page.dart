import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/presentation/pages/charts/nxt_chart_screen.dart';
import 'package:neocharts_exampleapp/presentation/pages/charts/nxt_scalper_chart_screen.dart';
import 'package:neocharts_exampleapp/presentation/widgets/chart_card.dart';

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
