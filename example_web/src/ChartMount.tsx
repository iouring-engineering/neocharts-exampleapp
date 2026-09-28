import { useEffect, useRef } from 'react'
import { mockDataReady } from './nxtChartHost'

interface ChartApp {
  addView(options: { hostElement: HTMLElement }): number
  removeView(viewId: number): void
}

// `_flutter.loader` is a global that `index.html`'s `flutter.js` script tag
// exposes (built by `fvm flutter build web`) -- an external, unversioned API
// used once below, so it's typed loosely rather than in full. See:
// https://docs.flutter.dev/platform-integration/web/embedding-flutter-web
declare global {
  interface Window {
    _flutter: {
      loader: {
        loadEntrypoint: (options: {
          entrypointUrl: string
          onEntrypointLoaded: (engineInitializer: any) => Promise<void>
        }) => void
      }
    }
  }
}

// The engine can only be booted once per page, so every mount shares this.
let chartApp: Promise<ChartApp> | null = null

function bootChartEngine(): Promise<ChartApp> {
  // Wait for the mock fixture before booting the engine: `NxtChartHost`'s
  // getters (e.g. `symbolInfo`) are synchronous and throw until it's ready.
  chartApp ??= mockDataReady.then(
    () =>
      new Promise<ChartApp>((resolve) => {
        // Base URL is VITE_SDK_ASSET_BASE (see .env / index.html's flutter.js
        // script tag) -- defaults to /build_web/, a symlink to
        // ../../../build/web for local/CI builds.
        window._flutter.loader.loadEntrypoint({
          entrypointUrl: `${import.meta.env.VITE_SDK_ASSET_BASE}main.dart.js`,
          onEntrypointLoaded: async (engineInitializer) => {
            const appRunner = await engineInitializer.initializeEngine({
              assetBase: import.meta.env.VITE_SDK_ASSET_BASE,
              multiViewEnabled: true,
            })
            resolve(await appRunner.runApp())
          },
        })
      }),
  )
  return chartApp
}

/**
 * Mounts one chart view into a full-size host div. Each mount gets a fresh
 * chart and unmounting disposes it -- so StrictMode's dev double-invoke ends
 * with exactly one view.
 */
export function ChartMount() {
  const hostRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    let removeView: (() => void) | null = null
    let unmounted = false

    bootChartEngine().then((app) => {
      if (unmounted || !hostRef.current) return
      const viewId = app.addView({ hostElement: hostRef.current })
      removeView = () => app.removeView(viewId)
    })

    return () => {
      unmounted = true
      removeView?.()
    }
  }, [])

  return <div ref={hostRef} style={{ width: '100%', height: '100%' }} />
}
