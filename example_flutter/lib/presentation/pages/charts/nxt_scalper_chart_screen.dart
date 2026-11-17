import 'package:material_ui/material_ui.dart';
import 'package:nxtchart/interface.dart';
import 'package:nxtchart/widgets.dart';

const _homeKey = String.fromEnvironment('NEOCHARTS_HOME_KEY');

class NxtScalperChartScreen extends StatelessWidget {
  const NxtScalperChartScreen({
    super.key,
    required this.dataProvider,
    required this.supportedResolutions,
    this.widgetOverrides,
  });

  final ChartInterface dataProvider;
  final NeoChartWidgetOverrides? widgetOverrides;

  /// See `NxtChartPage.supportedResolutions`.
  final List<String> supportedResolutions;

  @override
  Widget build(BuildContext context) {
    final homeKey = _homeKey.isEmpty ? null : _homeKey;
    return NxtChartPage(
      dataProvider: dataProvider,
      widgetOverrides: widgetOverrides,
      homeKey: homeKey,
      style: _demoStyle,
      supportedResolutions: supportedResolutions,
    );
  }
}

// Demo brand colors for both modes -- see the theming docs for all 14 tokens.
const _demoColors = NxtChartColorOverrides(
  primary: Color(0xFF7B1FA2),
  bullish: Color(0xFF26A69A),
  bearish: Color(0xFFEF5350),
);
const _demoStyle = NxtChartStyle(
  lightColors: _demoColors,
  darkColors: _demoColors,
);
