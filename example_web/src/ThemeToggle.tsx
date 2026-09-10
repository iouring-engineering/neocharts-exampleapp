import { useState } from 'react'
import { THEME_STORAGE_KEY } from './nxtChartHost'

type Theme = 'light' | 'dark' | null

function readTheme(): Theme {
  return localStorage.getItem(THEME_STORAGE_KEY) as Theme
}

function themeLabel(theme: Theme): string {
  return `Theme: ${theme === null ? 'System' : theme === 'light' ? 'Light' : 'Dark'}`
}

/**
 * Demo-only theme control -- cycles System -> Light -> Dark -> System via
 * `window.NxtChartHost.forcedBrightness` (backed by localStorage). Reloads
 * on every change since Flutter reads `forcedBrightness` once at boot, not
 * reactively. Landing-only: once the terminal (a Flutter canvas, not a React
 * layout) is open there's nowhere for this to sit without either overlaying
 * the chart's own UI or editing Flutter code, so change theme before opening it.
 */
export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>(readTheme)

  function cycleTheme() {
    const next: Theme = theme === null ? 'light' : theme === 'light' ? 'dark' : null
    if (next === null) {
      localStorage.removeItem(THEME_STORAGE_KEY)
    } else {
      localStorage.setItem(THEME_STORAGE_KEY, next)
    }
    setTheme(next)
    location.reload()
  }

  return (
    <button style={style} onClick={cycleTheme}>
      {themeLabel(theme)}
    </button>
  )
}

const style: React.CSSProperties = {
  cursor: 'pointer',
  border: '1px solid #555',
  background: '#2a2a2a',
  color: '#eee',
  borderRadius: 4,
  padding: '10px 24px',
  fontSize: 15,
  fontFamily: 'sans-serif',
  minWidth: 160,
}
