# NeoCharts — Flutter Example

Demonstrates the **package dependency** integration style: `nxtchart` added as a Flutter
dependency and mounted via `NeoChartPage`.

`NeoChartsRepository` (`lib/data/repositories/neo_charts_repository.dart`) is a
full reference host: it implements `NeoChartsHost` plus every optional capability
(OCO, alerts, OI and intraday analytics, funds, Top 5 options) over mock NIFTY,
BANKNIFTY and RELIANCE data. `NeoChartScreen` wires it into the page.

## Run it

`pubspec.yaml` holds a placeholder `nxtchart` git url. Replace the git
url/ref with the real one, or add a `pubspec_overrides.yaml` with a `path:`
override to a local SDK checkout, before running `pub get`.

NIFTY and BANKNIFTY are tradable here on purpose (Patrol trades them), while
the fixture-based Android, iOS and web examples treat them as indices.

```bash
fvm flutter pub get
fvm flutter run --dart-define=NEOCHARTS_HOME_KEY=<your key>
```

## Full guide

[Flutter Quick Start](https://docs-neocharts.iouring.com/docs/quick-start/flutter)
