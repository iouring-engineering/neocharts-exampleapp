import { ChartMount } from './ChartMount'
import { EmbeddedDashboard } from './EmbeddedDashboard'
import { Landing } from './Landing'
import { nxtChartHost } from './nxtChartHost'

// `window.NxtChartHost` is installed synchronously, before `flutter.js`
// finishes loading and calls into it. Its getters do need the fixture fetch
// to have completed though -- see `ChartMount`, which awaits
// `mockDataReady` before booting the Flutter engine.
window.NxtChartHost = nxtChartHost

// A real navigation (openRoute()/closeRequested() both assign `location.href`
// to a URL with a different `?route=` query param) rather than a same-document
// hash change -- each route is a genuinely distinct browser history entry, so
// back/forward work with zero extra JS. (A hash-based marker doesn't survive
// this: Flutter's web engine manages `location.hash` itself and strips it
// after boot, which silently broke back/forward -- both routes ended up at
// the same bare URL. `location.search` isn't touched by Flutter.)
const route = new URLSearchParams(location.search).get('route')

export default function App() {
  if (route === 'terminal') return <ChartMount />
  if (route === 'embedded') return <EmbeddedDashboard />
  return <Landing />
}
