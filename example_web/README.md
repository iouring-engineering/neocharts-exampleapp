# NeoCharts — Web Example

Demonstrates the **pre-built bundle** integration style: `window.NxtChartHost` implemented
in TypeScript, driving the compiled web bundle straight into the Terminal.

## Run it

```bash
npm install
npm run dev
```

`src/nxtChartHost.ts` is the reference `NxtChartHost` implementation — real, working mock
data, not just a stub.

## SDK bundle source

`VITE_SDK_ASSET_BASE` controls where the compiled SDK web bundle
(`flutter.js`, `main.dart.js`, `assets/`) is loaded from:

| Command | Reads | Loads the SDK from |
|---|---|---|
| `npm run dev` | `.env.development` | `/build_web/`, a symlink to the sibling Flutter build output |
| `npm run dev -- --mode cdn` | `.env` | the CDN |
| `npm run build` | `.env` | the CDN |

Each SDK release has its own CDN folder,
`https://cdn.nxtoption.com/neocharts-sdk/<version>/`. `.env` holds the current
one; change only that line to move to a new release.

CDN mode assumes whatever is hosted there is the SDK's `-cdn` tarball
variant — it fetches CanvasKit from Google's `gstatic.com` itself, since
CanvasKit is always requested relative to this app's own origin, never
relative to `VITE_SDK_ASSET_BASE`.

## Live demo

[demo-neocharts.iouring.com](https://demo-neocharts.iouring.com/)

## Full guide

[Web Quick Start](https://docs-neocharts.iouring.com/docs/quick-start/web)
