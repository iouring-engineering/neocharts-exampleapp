import { useEffect, useRef } from 'react'

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

    // Served from public/build_web, a symlink to ../../../build/web -- see
    // index.html's flutter.js script tag for why this can't be a plain
    // "../../build/web" relative path under Vite's dev server.
    window._flutter.loader.loadEntrypoint({
      entrypointUrl: '/build_web/main.dart.js',
      onEntrypointLoaded: async (engineInitializer) => {
        const appRunner = await engineInitializer.initializeEngine({
          hostElement: hostRef.current!,
          assetBase: '/build_web/',
        })
        await appRunner.runApp()
      },
    })
  }, [])

  return <div ref={hostRef} style={{ width: '100%', height: '100%' }} />
}
