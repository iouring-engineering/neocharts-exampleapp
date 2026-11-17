# NeoCharts — Android Example

Demonstrates the **native add-to-app** integration style: a cached Flutter engine running the
NeoCharts SDK, driven from Kotlin over the `neocharts/*` channels. It is a full reference host:
the core contract plus every optional capability (OCO, alerts, OI and intraday analytics, funds,
top options and close), over NIFTY, BANKNIFTY, SENSEX and RELIANCE from the shared `../mock/`
fixture.

- `ChartHost.kt`: the engine, bridge and lifecycle callback, built once per process, so
  rotating or switching dark mode keeps the open chart.
- `NeoChartsBridge.kt`: the `neocharts/lifecycle` calls (`mount` with a theme, `unmount`), the
  `neocharts/data` handler (`init` and every data method) and the six `neocharts/<event>` push
  channels.
- `TradingState.kt`: the mock broker (orders, positions, OCO, alerts, fills, action feedback).
- `MockDataSource.kt`: per-id reads of the fixture, plus candles and ticks (with market depth).

## Licence home key

Put the key in `local.properties` (untracked):

```properties
neocharts.homeKey=<your home key>
```

Without it the chart opens on the licence error screen.

## Run it

Build the SDK AAR first (`melos run bundle:android` in the SDK root), then open in Android
Studio, or:

```bash
./gradlew installDebug
```

Tests: `./gradlew testDebugUnitTest`.

## Full guide

[Android Quick Start](https://docs-neocharts.iouring.com/docs/quick-start/android)
