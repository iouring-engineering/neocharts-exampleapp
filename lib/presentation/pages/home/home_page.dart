import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:neocharts_exampleapp/data/datasources/benchmark_config.dart';
import 'package:neocharts_exampleapp/data/repositories/nxt_chart_repository.dart';
import 'package:neocharts_exampleapp/presentation/pages/charts/nxt_scalper_chart_screen.dart';
import 'package:neocharts_exampleapp/presentation/widgets/benchmark_control_panel.dart';
import 'package:neocharts_exampleapp/presentation/widgets/chart_card.dart';
import 'package:nxtchart/interface.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  final ChartInterface interface;

  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
    required this.interface,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Non-null once a benchmark control has been touched -- the
  // "NeoCharts" card then opens a fresh, purpose-configured interface
  // instead of widget.interface, leaving every other (non-benchmark) flow
  // through this page untouched.
  BenchmarkConfig? _benchmarkConfig;

  ChartInterface _resolveInterface() {
    final config = _benchmarkConfig;
    if (config == null) return widget.interface;

    return NxtChartRepository(
      storageKey: 'scalper_chart',
      liveDataEnabled: config.liveDataEnabled,
      streamRate: config.streamRate,
      benchmarkBarCount: config.datasetSize.candleCount,
    );
  }

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
                                onTap: widget.onToggleTheme,
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
                              title: 'NeoCharts',
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
                                    builder: (context) => NxtScalperChartScreen(
                                      dataProvider: _resolveInterface(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        // ─────────────────────────────
                        // BENCHMARK (Patrol perf suite) -- never in a
                        // release build, so it never reaches a store
                        // listing.
                        // ─────────────────────────────
                        if (!kReleaseMode) ...[
                          const SizedBox(height: 32),
                          BenchmarkControlPanel(
                            config: _benchmarkConfig ?? const BenchmarkConfig(),
                            onChanged: (config) =>
                                setState(() => _benchmarkConfig = config),
                          ),
                        ],

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      persistentFooterDecoration: BoxDecoration(border: Border()),
      persistentFooterButtons: [
        // ─────────────────────────────
        // FOOTER
        // ─────────────────────────────
        Center(
          child: Text(
            'BUILT BY IOURING',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.labelSmall?.color?.withValues(alpha: 0.35),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
