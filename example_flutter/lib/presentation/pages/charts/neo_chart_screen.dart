import 'package:material_ui/material_ui.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:nxtchart/widgets.dart';

const _homeKey = String.fromEnvironment('NEOCHARTS_HOME_KEY');

/// The chart page over one [host], with every optional capability wired in.
class NeoChartScreen extends StatelessWidget {
  const NeoChartScreen({super.key, required this.host});

  /// Disposed by the page when it unmounts; never reuse one across opens.
  final NeoChartsRepository host;

  @override
  Widget build(BuildContext context) {
    return NeoChartPage(
      host: host,
      oco: host,
      alerts: host,
      oiAnalytics: host,
      intradayAnalytics: host,
      fetchFunds: host.fetchFunds,
      fetchTopOptions: host.fetchTopOptions,
      onClose: () => Navigator.of(context).pop(),
      homeKey: _homeKey.isEmpty ? null : _homeKey,
      style: _demoStyle,
    );
  }
}

// Demo brand colors for both modes -- see the theming docs for all 14 tokens.
const _demoColors = NeoChartColorOverrides(
  primary: Color(0xFF7B1FA2),
  bullish: Color(0xFF26A69A),
  bearish: Color(0xFFEF5350),
);
const _demoStyle = NeoChartStyle(
  lightColors: _demoColors,
  darkColors: _demoColors,
);
