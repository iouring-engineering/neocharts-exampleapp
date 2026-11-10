import { useEffect, useRef } from 'react'
import { createHost, currentTheme, mockDataReady, THEME_STORAGE_KEY } from './neoChartsHost'
import type { NeoChartsHandle } from './neocharts-host'

/**
 * Mounts one chart into a full-size div through `neoCharts.mount`. The host's
 * timers stop on cleanup, so StrictMode's dev double-invoke, or leaving the
 * page before the mount resolves, leaves exactly one live host.
 */
export function ChartMount() {
  const hostRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const element = hostRef.current
    if (!element) return
    let cancelled = false
    let handle: NeoChartsHandle | null = null
    let stop: (() => void) | null = null

    const onStorage = (e: StorageEvent) => {
      if (e.key === THEME_STORAGE_KEY) handle?.setTheme(currentTheme())
    }
    window.addEventListener('storage', onStorage)

    void (async () => {
      await mockDataReady
      if (cancelled) return
      try {
        const created = createHost(element)
        stop = created.stop
        const mounted = await window.neoCharts.mount(element, created.host, {
          theme: currentTheme(),
        })
        // Cleanup already ran while the mount was in flight.
        if (cancelled) mounted.unmount()
        else handle = mounted
      } catch (err) {
        if (!cancelled) console.error('neoCharts.mount failed:', err)
      }
    })()

    return () => {
      cancelled = true
      window.removeEventListener('storage', onStorage)
      handle?.unmount()
      stop?.()
    }
  }, [])

  return <div ref={hostRef} style={{ width: '100%', height: '100%' }} />
}
