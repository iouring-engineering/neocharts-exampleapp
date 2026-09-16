import { ChartMount } from './ChartMount'
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

export default function App() {
  return <ChartMount />
}
