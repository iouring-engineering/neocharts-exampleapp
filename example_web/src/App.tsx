import { ChartMount } from './ChartMount'
import { nxtChartHost, startMockFeeds } from './nxtChartHost'

// Must be set before `flutter.js` finishes loading and calls into it --
// both happen well before this module's synchronous top-level code below
// returns, so there's no race.
window.NxtChartHost = nxtChartHost
startMockFeeds()

export default function App() {
  return <ChartMount />
}
