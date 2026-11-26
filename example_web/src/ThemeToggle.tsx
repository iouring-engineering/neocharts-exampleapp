import { THEME_STORAGE_KEY } from './neoChartsHost'

const DARK_TEXT = '#FFFFFF'
const LIGHT_TEXT = '#0A0A12'
// Same Material3 ColorScheme.fromSeed-derived cardColor as the Android/iOS
// ports' theme-toggle background (#6C63FF light / #8B7CFF dark seeds).
const LIGHT_CARD_COLOR = '#FCF8FF'
const DARK_CARD_COLOR = '#141318'

/**
 * The demo's sun/moon toggle: persists the choice under `THEME_STORAGE_KEY`
 * (the chart's mount theme reads it), then reports it via `onChange`.
 */
export function ThemeToggle({
  isDark,
  onChange,
  label,
}: {
  isDark: boolean
  onChange: (isDark: boolean) => void
  label: string
}) {
  const textColor = isDark ? DARK_TEXT : LIGHT_TEXT
  const cardColor = isDark ? DARK_CARD_COLOR : LIGHT_CARD_COLOR

  return (
    <button
      onClick={() => {
        const next = !isDark
        localStorage.setItem(THEME_STORAGE_KEY, next ? 'dark' : 'light')
        onChange(next)
      }}
      aria-label={label}
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
  )
}
