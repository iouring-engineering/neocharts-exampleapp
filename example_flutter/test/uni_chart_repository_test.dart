import 'package:flutter_test/flutter_test.dart';
import 'package:neocharts_exampleapp/data/repositories/neo_charts_repository.dart';
import 'package:neocharts_exampleapp/data/repositories/uni_chart_repository.dart';
import 'package:nxtchart/interface.dart';

final _today = DateTime.now();

OHLC bar(DateTime time, double open, double high, double low, double close) =>
    OHLC(
      time: time.millisecondsSinceEpoch,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 0,
    );

/// Fixed bars: two daily (yesterday closed at 90), three 1-minute today.
class _FixedBase extends NeoChartsRepository {
  _FixedBase() : super(liveDataEnabled: false);

  @override
  Future<List<OHLC>> loadData(CandleRequest request) async =>
      switch (request.intervalSeconds) {
        Duration.secondsPerDay => [
          bar(_today.subtract(const Duration(days: 1)), 80, 95, 75, 90),
          bar(_today, 100, 120, 70, 110),
        ],
        60 => [
          bar(_today, 100, 105, 95, 102),
          bar(_today, 102, 120, 101, 118),
          bar(_today, 118, 119, 70, 110),
        ],
        _ => [bar(_today, 1, 1, 1, 1)],
      };
}

CandleRequest request(int intervalSeconds) => CandleRequest(
  symbolId: 'NIFTY',
  from: 0,
  to: _today.millisecondsSinceEpoch,
  intervalSeconds: intervalSeconds,
  requiredBars: 3,
);

void main() {
  late UniChartRepository uni;

  setUp(() => uni = UniChartRepository(base: _FixedBase(), onAction: (_) {}));

  tearDown(() => uni.dispose());

  test('intraday load seeds the day; prev close is yesterday', () async {
    await uni.loadData(request(60));

    expect(uni.quote.value, (
      ltp: 110.0,
      open: 100.0,
      high: 120.0,
      low: 70.0,
      prevClose: 90.0,
    ));
  });

  test('weekly bars leave the quote unseeded', () async {
    await uni.loadData(request(7 * Duration.secondsPerDay));

    expect(uni.quote.value, isNull);
  });
}
