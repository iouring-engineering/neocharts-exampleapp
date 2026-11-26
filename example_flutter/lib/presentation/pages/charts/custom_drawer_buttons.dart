import 'package:material_ui/material_ui.dart';
import 'package:nxtchart/widgets.dart';

/// Host shortcuts added to the end of the chart's menu drawer
/// (`NeoChartConfig.customDrawerButtons`). Each reports in a snackbar where a
/// real host would open its own screen.
List<MenuDrawerButton> buildDrawerButtons(BuildContext context) {
  final color = Theme.of(context).colorScheme.onSurface;

  MenuDrawerButton button(IconData icon, String label, String screen) {
    return MenuDrawerButton(
      icon: Icon(icon, size: 20, color: color),
      label: label,
      onTap: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Open $screen'))),
    );
  }

  return [
    button(Icons.visibility_outlined, 'Watchlist', 'watchlist'),
    button(Icons.newspaper_outlined, 'News', 'market news'),
    button(Icons.dashboard_outlined, 'Dashboard', 'dashboard'),
    button(Icons.table_view_outlined, 'Reports', 'reports'),
  ];
}
