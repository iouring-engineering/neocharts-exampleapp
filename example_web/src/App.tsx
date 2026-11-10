import { ChartMount } from './ChartMount'
import { EmbeddedDashboard } from './EmbeddedDashboard'
import { Landing } from './Landing'

// A real navigation (openRoute()/`onClose` both assign `location.href`
// to a URL with a different `?route=` query param) rather than a same-document
// hash change -- each route is a genuinely distinct browser history entry, so
// back/forward work with zero extra JS. (The chart engine manages
// `location.hash` itself, so a hash-based marker wouldn't survive.)
const route = new URLSearchParams(location.search).get('route')

export default function App() {
  if (route === 'terminal') return <ChartMount />
  if (route === 'embedded') return <EmbeddedDashboard />
  return <Landing />
}
