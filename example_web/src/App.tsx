import { ChartMount } from './ChartMount'
import { EmbeddedDashboard } from './EmbeddedDashboard'
import { Landing } from './Landing'
import { nxtChartHost, startMockFeeds } from './nxtChartHost'

// `window.NxtChartHost` itself is installed synchronously, before `flutter.js`
// finishes loading and calls into it. Its getters do race the fixture fetch
// though: until `startMockFeeds()` resolves, every data read throws "must be
// awaited before use". In practice Flutter's boot is far slower than the local
// fetch, so the SDK only reads once the fixture is in -- but a slow or failed
// fetch will surface as a throw from a getter, not as silently stale data.
window.NxtChartHost = nxtChartHost
startMockFeeds().catch((err) => {
  console.error('Failed to start mock feeds:', err)
})

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
