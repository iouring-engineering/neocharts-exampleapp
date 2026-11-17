# NeoCharts — Web Example

Demonstrates the **pre-built bundle** integration style: a host object implemented in
TypeScript and mounted with `neoCharts.mount(element, host)`, driving the compiled web
bundle straight into the Terminal.

## Run it

```bash
npm install
npm run dev
```

`npm run dev` loads the SDK web bundle from `/build_web/`, a symlink to the SDK's
`build/web`, so build the bundle first, from the SDK root:

```bash
fvm flutter build web --target=lib/main_web.dart --no-web-resources-cdn
```

(Make sure `neocharts_core.wasm` is in the build's `assets/`.)

`src/neoChartsHost.ts` is the reference host (`createHost(element)`, typed by the vendored
`src/neocharts-host.d.ts`) — real, working mock data, not just a stub. It implements every
optional group (OCO, alerts, OI, intraday, funds, top options, close).

## SDK bundle source

`VITE_SDK_ASSET_BASE` controls where the compiled SDK web bundle
(`neocharts.js`, `main.dart.js`, `assets/`) is loaded from:

| Command | Reads | Loads the SDK from |
|---|---|---|
| `npm run dev` | `.env.development` | `/build_web/`, a symlink to the sibling Flutter build output |
| `npm run dev -- --mode cdn` | `.env` | the CDN |
| `npm run build` | `.env` | the CDN |

CDN mode (`--mode cdn`, `npm run build`) needs a CDN release that ships
`neocharts.js`; until the `.env` version has one, those pages stay blank.

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
