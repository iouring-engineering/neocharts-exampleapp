# NeoCharts — iOS Example

Demonstrates the **native add-to-app** integration style: a cached Flutter engine running the
NeoCharts SDK, driven from Swift over the `neocharts/*` channels. It is a full reference host:
the core contract plus every optional capability (OCO, alerts, OI and intraday analytics, funds,
top options and close), over NIFTY, BANKNIFTY, SENSEX and RELIANCE from the shared `../mock/`
fixture.

- `NeoChartsBridge.swift`: the `neocharts/lifecycle` calls (`mount` with a theme, `unmount`), the
  `neocharts/data` handler (`init` and every data method) and the six `neocharts/<event>` push
  channels.
- `TradingState.swift`: the mock broker (orders, positions, OCO, alerts, fills, action feedback).
- `MockDataSource.swift`: per-id reads of the fixture, plus candles and ticks.

## Licence home key

Set `NEOCHARTS_HOME_KEY=<your home key>` in the Xcode scheme's Run environment
(Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables). Keep it in your
local scheme (`xcuserdata`, untracked), not a shared one.

Without it the chart opens on the licence error screen.

## Run it

Run `fvm flutter pub get` in the SDK root first (it generates the `.ios/` module), then:

```bash
pod install
open example_ios.xcworkspace
```

Then run from Xcode.

## Full guide

[iOS Quick Start](https://docs-neocharts.iouring.com/docs/quick-start/ios)
