import { useEffect, useRef } from 'react'
import { indexSymbols } from './mockDataSource'
import { createHost, currentTheme, mockDataReady, THEME_STORAGE_KEY } from './neoChartsHost'
import type { NeoChartsHandle, NeoChartsToolbarItem } from './neocharts-host'
import chartTerminalIcon from './chart-terminal-logo.svg?raw'

/**
 * The host toolbar: an Indices menu (display only: picking an index does
 * nothing) and a Chart Terminal button that opens the terminal in a new tab.
 * Built after the mock data loads, since the menu lists its index symbols.
 */
function toolbar(): NeoChartsToolbarItem[] {
  return [
    {
      text: 'Indices',
      items: indexSymbols().map((symbol) => ({ text: symbol.name, onClick: () => {} })),
    },
    {
      text: 'Chart Terminal',
      icon: chartTerminalIcon,
      tooltip: 'Open the chart terminal in a new tab',
      onClick: () => window.open(`${location.pathname}?route=terminal`, '_blank'),
    },
  ]
}

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
          toolbar: toolbar(),
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
