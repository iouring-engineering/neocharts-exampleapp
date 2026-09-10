// Hand-written aggregator so the whole patrol_test suite runs as one
// continuous app session under `patrol develop` (single app launch, no
// relaunch between files or test cases — Orchestrator never enters the
// picture in develop mode). Not generated; safe to keep across runs.
//
// IMPORTANT: main() must stay synchronous (no `async`, no manual
// PlatformAutomator/PatrolBinding init) — this file is itself wrapped in a
// `group()` call by the outer auto-generated test_bundle.dart when used as
// a develop target, and group() callbacks must be synchronous.
// ignore_for_file: type=lint

import 'package:flutter_test/flutter_test.dart';

import 'alerts/alert_chart_marker_test.dart' as alerts__alert_chart_marker_test;
import 'alerts/create_alert_test.dart' as alerts__create_alert_test;
import 'alerts/delete_alert_test.dart' as alerts__delete_alert_test;
import 'alerts/modify_alert_test.dart' as alerts__modify_alert_test;
import 'analysis/analysis_tabs_test.dart' as analysis__analysis_tabs_test;
import 'analysis/oi_analysis_chart_test.dart'
    as analysis__oi_analysis_chart_test;
import 'analysis/oi_change_chart_test.dart' as analysis__oi_change_chart_test;
import 'analysis/pcr_chart_test.dart' as analysis__pcr_chart_test;
import 'analysis/price_and_atm_charts_test.dart'
    as analysis__price_and_atm_charts_test;
import 'benchmark_perf_test.dart' as benchmark_perf_test;
import 'chart_type_switching_test.dart' as chart_type_switching_test;
import 'indicator_toggling_test.dart' as indicator_toggling_test;
import 'interval_switching_test.dart' as interval_switching_test;
import 'option_chain_test.dart' as option_chain_test;
import 'order_preferences_test.dart' as order_preferences_test;
import 'orders/cancel_order_test.dart' as orders__cancel_order_test;
import 'orders/modify_order_test.dart' as orders__modify_order_test;
import 'orders/oco/oco_cancel_test.dart' as orders__oco__oco_cancel_test;
import 'orders/oco/oco_create_test.dart' as orders__oco__oco_create_test;
import 'orders/oco/oco_modify_test.dart' as orders__oco__oco_modify_test;
import 'orders/order_chart_marker_test.dart' as orders__order_chart_marker_test;
import 'orders/place_order_test.dart' as orders__place_order_test;
import 'pl_test.dart' as pl_test;
import 'positions/add_position_test.dart' as positions__add_position_test;
import 'positions/adjust_position_test.dart' as positions__adjust_position_test;
import 'positions/exit_position_test.dart' as positions__exit_position_test;
import 'positions/group_adjust/group_adjust_button_test.dart'
    as positions__group_adjust__group_adjust_button_test;
import 'positions/group_adjust/group_adjust_item_test.dart'
    as positions__group_adjust__group_adjust_item_test;
import 'positions/group_adjust/group_adjust_option_chain_test.dart'
    as positions__group_adjust__group_adjust_option_chain_test;
import 'positions/group_adjust/group_adjust_submit_test.dart'
    as positions__group_adjust__group_adjust_submit_test;
import 'positions/position_chart_drag_test.dart'
    as positions__position_chart_drag_test;
import 'positions/positions_list_test.dart' as positions__positions_list_test;
import 'range_switching_test.dart' as range_switching_test;
import 'top_options_test.dart' as top_options_test;
import 'trading_test.dart' as trading_test;

void main() {
  group('alerts.alert_chart_marker_test', alerts__alert_chart_marker_test.main);
  group('alerts.create_alert_test', alerts__create_alert_test.main);
  group('alerts.delete_alert_test', alerts__delete_alert_test.main);
  group('alerts.modify_alert_test', alerts__modify_alert_test.main);
  group('analysis.analysis_tabs_test', analysis__analysis_tabs_test.main);
  group(
    'analysis.oi_analysis_chart_test',
    analysis__oi_analysis_chart_test.main,
  );
  group('analysis.oi_change_chart_test', analysis__oi_change_chart_test.main);
  group('analysis.pcr_chart_test', analysis__pcr_chart_test.main);
  group(
    'analysis.price_and_atm_charts_test',
    analysis__price_and_atm_charts_test.main,
  );
  group('benchmark_perf_test', benchmark_perf_test.main);
  group('chart_type_switching_test', chart_type_switching_test.main);
  group('indicator_toggling_test', indicator_toggling_test.main);
  group('interval_switching_test', interval_switching_test.main);
  group('option_chain_test', option_chain_test.main);
  group('order_preferences_test', order_preferences_test.main);
  group('orders.cancel_order_test', orders__cancel_order_test.main);
  group('orders.modify_order_test', orders__modify_order_test.main);
  group('orders.oco.oco_cancel_test', orders__oco__oco_cancel_test.main);
  group('orders.oco.oco_create_test', orders__oco__oco_create_test.main);
  group('orders.oco.oco_modify_test', orders__oco__oco_modify_test.main);
  group('orders.order_chart_marker_test', orders__order_chart_marker_test.main);
  group('orders.place_order_test', orders__place_order_test.main);
  group('pl_test', pl_test.main);
  group('positions.add_position_test', positions__add_position_test.main);
  group('positions.adjust_position_test', positions__adjust_position_test.main);
  group('positions.exit_position_test', positions__exit_position_test.main);
  group(
    'positions.group_adjust.group_adjust_button_test',
    positions__group_adjust__group_adjust_button_test.main,
  );
  group(
    'positions.group_adjust.group_adjust_item_test',
    positions__group_adjust__group_adjust_item_test.main,
  );
  group(
    'positions.group_adjust.group_adjust_option_chain_test',
    positions__group_adjust__group_adjust_option_chain_test.main,
  );
  group(
    'positions.group_adjust.group_adjust_submit_test',
    positions__group_adjust__group_adjust_submit_test.main,
  );
  group(
    'positions.position_chart_drag_test',
    positions__position_chart_drag_test.main,
  );
  group('positions.positions_list_test', positions__positions_list_test.main);
  group('range_switching_test', range_switching_test.main);
  group('top_options_test', top_options_test.main);
  group('trading_test', trading_test.main);
}
