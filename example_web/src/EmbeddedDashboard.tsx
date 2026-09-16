import { ChartMount } from './ChartMount'
import { THEME_STORAGE_KEY } from './nxtChartHost'

const NAV_ITEMS = ['Overview', 'Positions', 'Orders', 'Alerts', 'Settings']

const DARK_BACKGROUND = '#090B10'
const LIGHT_BACKGROUND = '#F5F7FB'
const DARK_TEXT = '#FFFFFF'
const LIGHT_TEXT = '#0A0A12'

/**
 * Demo-only page showing the chart embedded inline within a host page's own
 * layout, rather than taking over the whole viewport -- the second
 * integration pattern this reference app demonstrates (alongside opening in
 * a new tab). `ChartMount` itself needs no changes: it already renders into
 * a 100%/100% host div, so it fills whatever container it's placed in.
 *
 * The surrounding chrome (header/sidebar) follows the same persisted
 * `forcedBrightness` choice the landing page's toggle set (and that the
 * chart itself reads at boot) rather than a fixed dark palette, so a host
 * page embedding the chart in light mode doesn't get a dark navbar around
 * a light chart.
 */
export function EmbeddedDashboard() {
  const isDark = localStorage.getItem(THEME_STORAGE_KEY) !== 'light'
  const background = isDark ? DARK_BACKGROUND : LIGHT_BACKGROUND
  const textColor = isDark ? DARK_TEXT : LIGHT_TEXT
  const overlay = (alpha: number) => (isDark ? `rgba(255,255,255,${alpha})` : `rgba(0,0,0,${alpha})`)

  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background,
        color: textColor,
        fontFamily: 'Roboto, sans-serif',
      }}
    >
      <div
        style={{
          height: 56,
          flexShrink: 0,
          display: 'flex',
          alignItems: 'center',
          padding: '0 20px',
          borderBottom: `1px solid ${overlay(0.08)}`,
          fontWeight: 700,
        }}
      >
        IOURING
      </div>

      <div style={{ flex: 1, display: 'flex', minHeight: 0 }}>
        <div
          style={{
            width: 180,
            flexShrink: 0,
            padding: '20px 12px',
            borderRight: `1px solid ${overlay(0.08)}`,
          }}
        >
          {NAV_ITEMS.map((item, i) => (
            <div
              key={item}
              style={{
                padding: '10px 12px',
                borderRadius: 8,
                fontSize: 14,
                marginBottom: 4,
                background: i === 0 ? overlay(0.08) : 'transparent',
                opacity: i === 0 ? 1 : 0.6,
              }}
            >
              {item}
            </div>
          ))}
        </div>

        <div style={{ flex: 1, minWidth: 0, padding: 16 }}>
          <ChartMount />
        </div>
      </div>
    </div>
  )
}
