// apps/example_web/src/Landing.tsx
import type { ReactNode } from 'react'
import { useState } from 'react'
import { THEME_STORAGE_KEY } from './nxtChartHost'

function openRoute(route: 'terminal' | 'embedded') {
  // A query param, not a hash -- Flutter's web engine manages `location.hash`
  // itself and strips this app's own hash-based marker once it boots, which
  // silently broke browser back/forward (both the landing and terminal
  // pages ended up at the same bare URL). `location.search` isn't touched
  // by Flutter, so this survives and back/forward works correctly.
  location.href = `${location.pathname}?route=${route}`
}

const DARK_BACKGROUND = '#090B10'
const LIGHT_BACKGROUND = '#F5F7FB'
const DARK_TEXT = '#FFFFFF'
const LIGHT_TEXT = '#0A0A12'
// Same Material3 ColorScheme.fromSeed-derived cardColor as the Android/iOS
// ports' theme-toggle background (#6C63FF light / #8B7CFF dark seeds).
const LIGHT_CARD_COLOR = '#FCF8FF'
const DARK_CARD_COLOR = '#141318'
const LOGO_GRADIENT = 'linear-gradient(90deg, #7C5CFF, #4B8BFF)'
const CARD_GRADIENT = 'linear-gradient(135deg, #00A884, #00C6A2)'

/**
 * Demo-only landing screen -- a real host decides its own route. This
 * card just sets the URL hash; `lib/main_web.dart` never sees this
 * screen -- Flutter only boots once a route has been chosen, see `App.tsx`.
 * Ported from example_flutter's home_page.dart/chart_card.dart -- same
 * layout/colors/copy. The sun/moon toggle both switches this landing page's
 * own dark/light look (matching Android/iOS's local toggle state) AND
 * persists the choice to `forcedBrightness` (via `THEME_STORAGE_KEY`) so the
 * chart renders in the same theme once opened -- `window.NxtChartHost`
 * reads that key once at Flutter boot, which happens on a fresh page load
 * after `openRoute`, so no reload is needed here.
 */
/** One of the two integration-pattern cards on the landing page, styled like the original NeoCharts hero card (gradient, decorative circles, icon chip). */
function IntegrationCard({
  icon,
  title,
  subtitle,
  actionLabel,
  onClick,
}: {
  icon: ReactNode
  title: string
  subtitle: string
  actionLabel: string
  onClick: () => void
}) {
  return (
    <div
      onClick={onClick}
      style={{
        position: 'relative',
        flex: '1 1 280px',
        minWidth: 280,
        height: 230,
        borderRadius: 28,
        background: CARD_GRADIENT,
        overflow: 'hidden',
        cursor: 'pointer',
        boxShadow: '0 15px 30px rgba(0, 168, 132, 0.20)',
      }}
    >
      <div
        style={{
          position: 'absolute',
          top: -50,
          right: -50,
          width: 170,
          height: 170,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.08)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          bottom: -80,
          right: 45,
          width: 180,
          height: 180,
          borderRadius: '50%',
          background: 'rgba(255,255,255,0.05)',
        }}
      />

      <div
        style={{
          position: 'relative',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          padding: 28,
          boxSizing: 'border-box',
        }}
      >
        <div
          style={{
            width: 52,
            height: 52,
            borderRadius: 16,
            background: 'rgba(255,255,255,0.15)',
            border: '1px solid rgba(255,255,255,0.18)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            {icon}
          </svg>
        </div>

        <div style={{ flex: 1 }} />

        <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: -0.5 }}>{title}</div>
        <div style={{ height: 7 }} />
        <div style={{ fontSize: 14, opacity: 0.72 }}>{subtitle}</div>
        <div style={{ height: 18 }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, fontWeight: 700 }}>
          <span>{actionLabel}</span>
          <span>→</span>
        </div>
      </div>
    </div>
  )
}

export function Landing() {
  const [isDark, setIsDark] = useState(() => localStorage.getItem(THEME_STORAGE_KEY) !== 'light')
  const background = isDark ? DARK_BACKGROUND : LIGHT_BACKGROUND
  const textColor = isDark ? DARK_TEXT : LIGHT_TEXT
  const cardColor = isDark ? DARK_CARD_COLOR : LIGHT_CARD_COLOR

  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        background,
        fontFamily: 'Roboto, sans-serif',
        color: textColor,
      }}
    >
      <div style={{ flex: 1, overflowY: 'auto' }}>
        <div style={{ maxWidth: 1200, margin: '0 auto', padding: 24 }}>
          <div style={{ display: 'flex', alignItems: 'center' }}>
            <div
              style={{
                width: 46,
                height: 46,
                borderRadius: 14,
                background: LOGO_GRADIENT,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 20,
              }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path
                  d="M3 17L9 11L13 15L21 7"
                  stroke="white"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>
            <div style={{ marginLeft: 14 }}>
              <div style={{ fontSize: 20, fontWeight: 800, letterSpacing: -0.5 }}>NeoCharts</div>
              <div style={{ fontSize: 12, opacity: 0.55 }}>Trading intelligence</div>
            </div>
            <div style={{ flex: 1 }} />
            <button
              onClick={() => {
                const next = !isDark
                setIsDark(next)
                localStorage.setItem(THEME_STORAGE_KEY, next ? 'dark' : 'light')
              }}
              aria-label="Toggle landing page theme"
              style={{
                width: 44,
                height: 44,
                borderRadius: 14,
                background: cardColor,
                border: 'none',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              {isDark ? (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="5" fill={textColor} />
                  <g stroke={textColor} strokeWidth="2" strokeLinecap="round">
                    <line x1="12" y1="1" x2="12" y2="3" />
                    <line x1="12" y1="21" x2="12" y2="23" />
                    <line x1="1" y1="12" x2="3" y2="12" />
                    <line x1="21" y1="12" x2="23" y2="12" />
                    <line x1="4.2" y1="4.2" x2="5.6" y2="5.6" />
                    <line x1="18.4" y1="18.4" x2="19.8" y2="19.8" />
                    <line x1="4.2" y1="19.8" x2="5.6" y2="18.4" />
                    <line x1="18.4" y1="5.6" x2="19.8" y2="4.2" />
                  </g>
                </svg>
              ) : (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="9" fill={textColor} />
                  <circle cx="17" cy="9" r="8" fill={cardColor} />
                </svg>
              )}
            </button>
          </div>

          <div style={{ height: 70 }} />

          <div
            style={{
              fontSize: 34,
              fontWeight: 800,
              letterSpacing: -1.5,
              lineHeight: 1.05,
              whiteSpace: 'pre-line',
            }}
          >
            {'Choose your\nchart workspace.'}
          </div>

          <div style={{ height: 18 }} />

          <div style={{ fontSize: 16, lineHeight: 1.6, opacity: 0.6, maxWidth: 640 }}>
            Explore powerful charting tools designed for analysis, strategy and precision trading.
          </div>

          <div style={{ height: 44 }} />

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 20 }}>
            <IntegrationCard
              icon={
                <path
                  d="M18 13V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14L21 3"
                  stroke="white"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              }
              title="Standalone"
              subtitle="Launch the workspace in its own browser tab"
              actionLabel="Open in new tab"
              onClick={() => window.open(`${location.pathname}?route=terminal`, '_blank')}
            />
            <IntegrationCard
              icon={
                <>
                  <rect x="3" y="3" width="7" height="9" rx="1.5" stroke="white" strokeWidth="2" fill="none" />
                  <rect x="14" y="3" width="7" height="5" rx="1.5" stroke="white" strokeWidth="2" fill="none" />
                  <rect x="14" y="12" width="7" height="9" rx="1.5" stroke="white" strokeWidth="2" fill="none" />
                  <rect x="3" y="16" width="7" height="5" rx="1.5" stroke="white" strokeWidth="2" fill="none" />
                </>
              }
              title="Embedded"
              subtitle="See it embedded inline within a host page"
              actionLabel="View embedded demo"
              onClick={() => openRoute('embedded')}
            />
          </div>

          <div style={{ height: 60 }} />
        </div>
      </div>

      {/*
       * Pinned to the viewport bottom (a sibling of the scroll wrapper
       * above, not inside it), matching Flutter's Scaffold.persistentFooterButtons
       * semantics -- the footer stays visible regardless of scroll position
       * or content height. Padding derived from Flutter's actual Scaffold
       * internals: persistentFooterButtons wraps its child in
       * `Padding(EdgeInsets.all(8))` inside an OverflowBar (scaffold.dart),
       * plus home_page.dart's own trailing SizedBox(height: 20) after the
       * footer text -- 8 top, 8 + 20 = 28 bottom.
       */}
      <div
        style={{
          textAlign: 'center',
          fontSize: 11,
          fontWeight: 700,
          letterSpacing: 2,
          opacity: 0.35,
          padding: '8px 24px 28px',
        }}
      >
        BUILT BY IOURING
      </div>
    </div>
  )
}
