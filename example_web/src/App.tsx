import { ChartMount } from './ChartMount'
import { Landing } from './Landing'
import { nxtChartHost, startMockFeeds } from './nxtChartHost'

// Must be set before `flutter.js` finishes loading and calls into it --
// both happen well before this module's synchronous top-level code below
// returns, so there's no race.
window.NxtChartHost = nxtChartHost
startMockFeeds()

const chosenRoute = location.hash === '#/terminal'

export default function App() {
  return chosenRoute ? <ChartMount /> : <Landing />
}
