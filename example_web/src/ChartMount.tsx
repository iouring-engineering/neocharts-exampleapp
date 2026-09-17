import { useEffect, useRef } from 'react'
import { mockDataReady } from './nxtChartHost'

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

/** Mounts the compiled NxtChart web bundle into a full-size host div. */
export function ChartMount() {
  const hostRef = useRef<HTMLDivElement>(null)
  const loaded = useRef(false)

  useEffect(() => {
    // Guards against React StrictMode's double-invoked effects in dev --
    // loadEntrypoint must only ever run once per page load.
    if (loaded.current || !hostRef.current) return
    loaded.current = true

    // Wait for the mock fixture before booting the engine: `NxtChartHost`'s
    // getters (e.g. `symbolInfo`) are synchronous and throw until it's ready.
    mockDataReady.then(() => {
      // Base URL is VITE_SDK_ASSET_BASE (see .env / index.html's flutter.js
      // script tag) -- defaults to /build_web/, a symlink to
      // ../../../build/web for local/CI builds.
      window._flutter.loader.loadEntrypoint({
        entrypointUrl: `${import.meta.env.VITE_SDK_ASSET_BASE}main.dart.js`,
        onEntrypointLoaded: async (engineInitializer) => {
          const appRunner = await engineInitializer.initializeEngine({
            hostElement: hostRef.current!,
            assetBase: import.meta.env.VITE_SDK_ASSET_BASE,
          })
          await appRunner.runApp()
        },
      })
    })
  }, [])

  return <div ref={hostRef} style={{ width: '100%', height: '100%' }} />
}
