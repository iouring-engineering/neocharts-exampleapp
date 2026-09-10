import { ThemeToggle } from './ThemeToggle'

function openRoute(route: 'terminal') {
  location.hash = `/${route}`
  location.reload()
}

/**
 * Demo-only landing screen -- a real host decides its own route. This
 * button just sets the URL hash; `lib/main_web.dart` never sees this
 * screen -- Flutter only boots once a route has been chosen, see `App.tsx`.
 * `ThemeToggle` only renders here, not inside the terminal -- there's no
 * React layout to sit in there (it's a Flutter canvas), only overlaying the
 * chart's own UI or editing Flutter code, neither of which is worth it for
 * a demo control.
 */
export function Landing() {
  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 12,
        fontFamily: 'sans-serif',
        background: '#1c1c1c',
      }}
    >
      <button style={buttonStyle} onClick={() => openRoute('terminal')}>
        Open Terminal
      </button>
      <ThemeToggle />
    </div>
  )
}

const buttonStyle: React.CSSProperties = {
  cursor: 'pointer',
  border: '1px solid #555',
  background: '#2a2a2a',
  color: '#eee',
  borderRadius: 4,
  padding: '10px 24px',
  fontSize: 15,
  minWidth: 160,
}
