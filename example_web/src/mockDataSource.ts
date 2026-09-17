// apps/example_web/src/mockDataSource.ts
//
// Reads the shared fixture (bundled as public/{symbols,oi,orders,positions,
// oco_orders}.json, symlinked from apps/mock/) and serves it as plain reads,
// plus this platform's own native live-tick and candle-walk generation
// widened to every symbol in the fixture.

interface SymbolInfo {
  id: string
  name: string
  // Omitted for non-tradable index symbols (see indexSymbols in the
  // fixture) -- there's no lot to trade.
  lotSize?: number
  precision: number
  tickSize: number
  exchange?: string
  expiry?: string
  strike?: string
  optType?: 'CE' | 'PE'
  weekly?: 'Y' | 'N'
  // Underlying symbol id -- e.g. "NIFTY" on a NIFTY option/future, "BANKNIFTY"
  // on a BANKNIFTY one. Omitted on the underlying itself (an index or
  // equity). The Dart SDK's JsChartInterface uses this to scope
  // optionSymbols/futureSymbols to whichever underlying is currently
  // charted, out of this fixture's full multi-underlying universe.
  undID?: string
}

interface Fixture {
  niftySymbol: SymbolInfo
  optionChain: SymbolInfo[]
  futureSymbols: SymbolInfo[]
  indexSymbols: SymbolInfo[]
  equitySymbols: SymbolInfo[]
  basePrices: Record<string, number>
  topOptionsByVolume: {
    symId: string
    name: string
    optType: string
    exchange: string
  }[]
  oi: {
    byStrike: { calls: Record<string, number>; puts: Record<string, number> }
    changeByStrike: {
      calls: Record<string, number>
      puts: Record<string, number>
    }
    analysisAroundAtm: {
      calls: Record<string, { oi: number; oiChg: number; prevOi: number }>
      puts: Record<string, { oi: number; oiChg: number; prevOi: number }>
    }
  }
  pcrIntraday: {
    offsetMinutes: number
    price: number
    pcr: Record<string, number>
  }[]
  atmStraddleIntraday: Record<string, { offsetMinutes: number; atmStraddlePrice: number }[]>
  atmIvIntraday: { offsetMinutes: number; atmIv: number }[]
  seedOrders: Record<string, unknown>[]
  seedPositions: Record<string, unknown>[]
  seedOcoOrders: Record<string, unknown>[]
}

const REQUIRED_KEYS: (keyof Fixture)[] = [
  'niftySymbol',
  'optionChain',
  'futureSymbols',
  'indexSymbols',
  'equitySymbols',
  'basePrices',
  'topOptionsByVolume',
  'oi',
  'pcrIntraday',
  'atmStraddleIntraday',
  'atmIvIntraday',
  'seedOrders',
  'seedPositions',
  'seedOcoOrders',
]

let fixture: Fixture | null = null

const FIXTURE_FILES = ['symbols', 'oi', 'orders', 'positions', 'oco_orders']

export async function loadMockData(): Promise<void> {
  const json = {} as Fixture
  for (const name of FIXTURE_FILES) {
    const response = await fetch(`/${name}.json`)
    // Check before parsing: a miss can come back as a real 404 whose body
    // still JSON-parses into something confusing, or as the SPA's index.html.
    if (!response.ok) {
      throw new Error(`Failed to load ${name}.json: HTTP ${response.status}`)
    }
    Object.assign(json, await response.json())
  }
  for (const key of REQUIRED_KEYS) {
    if (!(key in json)) throw new Error(`mock fixture is missing required key: ${key}`)
  }
  fixture = json
}

function data(): Fixture {
  if (!fixture) throw new Error('mockDataSource.loadMockData() must be awaited before use')
  return fixture
}

// Looks up any tradable instrument (future or option) by id -- the index
// itself is deliberately excluded, since it isn't tradable (see
// seedOrders/seedPositions, which resolve each row's own symID through
// this instead of a single hardcoded symbol).
function symbolByID(symID: string): SymbolInfo {
  const found = [...data().futureSymbols, ...data().optionChain].find((s) => s.id === symID)
  if (!found) throw new Error(`mock fixture: unknown symID ${symID}`)
  return found
}

// A fast, deterministic string hash mapped to [0, 1) -- gives each symbol
// its own stable wave phase without needing a seeded PRNG library.
function seededUnit(seed: string): number {
  let h = 2166136261
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return (h >>> 0) / 4294967296
}

// Smoothly interpolates between pseudo-random values at fixed-size time
// "lattice" points (value noise) -- unlike a fixed-period sine wave, the
// lattice values themselves are independent per symbol/spacing/index, so
// the resulting path looks like irregular price action, never repeats,
// and still only depends on (symbolId, ts).
function latticeNoise(symbolId: string, ts: number, spacingMs: number): number {
  const n = Math.floor(ts / spacingMs)
  const frac = ts / spacingMs - n
  const a = seededUnit(`${symbolId}:${spacingMs}:${n}`) * 2 - 1
  const b = seededUnit(`${symbolId}:${spacingMs}:${n + 1}`) * 2 - 1
  const smooth = frac * frac * (3 - 2 * frac) // smoothstep, avoids kinks at lattice points
  return a + (b - a) * smooth
}

// Pure function of (symbolId, timestamp) -- deterministic and idempotent,
// so any number of independent `loadData` calls (chart_bloc, analysis_bloc,
// pan-back reloads all call it separately) return identical bars for the
// same symbol/timestamps, and live ticks (which just evaluate this at
// `Date.now()`) always continue exactly where the last historical bar left
// off. The previous version cached a single mutable "current price" per
// symbol and random-walked it forward on every call -- fine for one caller,
// but two independent calls (or a reload) diverged onto different paths,
// which showed up as one oversized candle where they met.
// Three octaves of lattice noise (slow drift down to fast jitter), summed
// -- looks like real price action rather than a clean periodic wave.
function priceAt(symbolId: string, ts: number): number {
  const base = data().basePrices[symbolId] ?? 22600
  const wave =
    latticeNoise(symbolId, ts, 20 * 60_000) * (base * 0.012) +
    latticeNoise(symbolId, ts, 3 * 60_000) * (base * 0.005) +
    latticeNoise(symbolId, ts, 20_000) * (base * 0.0015)
  return Math.max(0.5, base + wave)
}

function pad2(n: number): string {
  return String(n).padStart(2, '0')
}

// "dd-MM-yyyy HH:mm:ss" -- matches lib/src/extensions/string_x.dart's
// formatTime() parser, not ISO-8601 (see trade_interface.dart's ordTime doc).
function formatOrdTime(offsetMinutes: number): string {
  const d = new Date(Date.now() - offsetMinutes * 60_000)
  return (
    `${pad2(d.getDate())}-${pad2(d.getMonth() + 1)}-${d.getFullYear()} ` +
    `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`
  )
}

// -------------------------------------------------------------------------
// Static fixture reads
// -------------------------------------------------------------------------

export function symbolInfoJson(): string {
  return JSON.stringify(data().niftySymbol)
}
export function optionSymbolsJson(): string {
  return JSON.stringify(data().optionChain)
}
// Unlike the bare chain `optionSymbols` returns, `fetchOptionDetails` requires
// the underlying's own symbol info as the first element (the one entry without
// an `optType`) so the chart can resolve the spot price -- see
// MKTDataInterface.fetchOptionDetails.
export function fetchOptionDetailsJson(): string {
  return JSON.stringify([data().niftySymbol, ...data().optionChain])
}
export function futureSymbolsJson(): string {
  return JSON.stringify(data().futureSymbols)
}
export function indexSymbolsJson(): string {
  return JSON.stringify(data().indexSymbols)
}

// `sessions` is an array indexed by weekday (0 = Monday ... 6 = Sunday), each
// entry an array of "HHMM-HHMM" ranges and an empty array for a non-trading
// day -- see MarketTiming.fromJson in lib/src/models/market_timing.dart.
// Open every hour of every day -- a real exchange trades ~6h on weekdays
// only, but this is a demo: it should show live movement no matter when
// someone runs it, not just 09:15-15:30 IST on a weekday.
export function marketTimingJson(): string {
  const sessions = Array.from({ length: 7 }, () => ['0000-2359'])
  return JSON.stringify({
    timezone: 'Asia/Kolkata',
    sessions,
    holidays: [],
    special: {},
  })
}

export function chartTopOptionsJson(): string {
  return JSON.stringify(data().topOptionsByVolume)
}

// Keyed by underlying id, one [ceSymbolInfo, peSymbolInfo] pair (or null,
// if that underlying has no option chain) per entry -- NOT the bare
// [ce, pe] pair MKTDataInterface.atmSymbols (lib/src/interface/
// market_data_interface.dart) itself documents, since this function has
// no notion of "which underlying is currently charted" (window.
// NxtChartHost is one global object, not scoped per JsChartInterface
// instance). JsChartInterface.atmSymbols picks its own current
// underlying's pair back out of this and re-encodes it as the documented
// bare-pair shape, so nothing above that layer (chart_layout_preset.dart,
// docs, real hosts on other platforms) sees this indirection.
export function atmSymbolsJson(): string {
  const result: Record<string, [SymbolInfo, SymbolInfo] | null> = {}
  for (const underlying of data().indexSymbols) {
    const base = data().basePrices[underlying.id] ?? 0
    const chain = data().optionChain.filter((o) => o.undID === underlying.id)
    if (chain.length === 0) {
      result[underlying.id] = null
      continue
    }
    const atmStrike = chain.reduce((closest, opt) =>
      Math.abs(Number(opt.strike) - base) < Math.abs(Number(closest.strike) - base) ? opt : closest,
    )
    const call = chain.find((o) => o.strike === atmStrike.strike && o.optType === 'CE')
    const put = chain.find((o) => o.strike === atmStrike.strike && o.optType === 'PE')
    result[underlying.id] = call && put ? [call, put] : null
  }
  return JSON.stringify(result)
}

export function searchSymbols(query: string): string {
  const keyword = query.trim().toLowerCase()
  if (!keyword) return JSON.stringify([])

  // `niftySymbol` isn't listed separately here -- it's the same "NIFTY"
  // entry `indexSymbols` already carries, and including both would show
  // "NIFTY 50" twice in results.
  const universe = [
    ...data().optionChain,
    ...data().futureSymbols,
    ...data().indexSymbols,
    ...data().equitySymbols,
  ]
  const matches = universe.filter(
    (s) => s.name.toLowerCase().includes(keyword) || s.id.toLowerCase().includes(keyword),
  )
  return JSON.stringify(matches)
}

export function fetchOIAnalysisJson(): string {
  return JSON.stringify(data().oi.analysisAroundAtm)
}
export function fetchOIChangeJson(): string {
  return JSON.stringify(data().oi.changeByStrike)
}
export function fetchOIJson(): string {
  return JSON.stringify(data().oi.byStrike)
}

function withResolvedTimes<T extends { offsetMinutes: number }>(
  rows: T[],
): (Omit<T, 'offsetMinutes'> & { time: number })[] {
  const now = Date.now()
  return rows.map(({ offsetMinutes, ...rest }) => ({
    ...rest,
    time: now - offsetMinutes * 60_000,
  }))
}

export function fetchPcrIntradayJson(): string {
  return JSON.stringify(withResolvedTimes(data().pcrIntraday))
}
export function fetchAtmIvIntradayJson(): string {
  return JSON.stringify(withResolvedTimes(data().atmIvIntraday))
}
export function fetchAtmStraddleIntradayJson(): string {
  const resolved: Record<string, unknown> = {}
  for (const [expiry, rows] of Object.entries(data().atmStraddleIntraday)) {
    resolved[expiry] = withResolvedTimes(rows)
  }
  return JSON.stringify(resolved)
}

// Bug fix (found while transcribing this brief, same class of defect the
// Android/iOS sibling tasks hit independently): the fixture's
// `seedOrders[0]` carries `ordTimeOffsetMinutes` (same offset-minutes
// convention as `pcrIntraday`/`atmIvIntraday`/`atmStraddleIntraday`), not a
// resolved `ordTime`. A plain spread would leak the raw offset field and
// leave `ordTime` missing, so `Order.ordTime` (see
// lib/src/models/order.dart) would default to a blank string. Resolve it
// into the "dd-MM-yyyy HH:mm:ss" string trade_interface.dart documents.
export const seedOrders = () =>
  data().seedOrders.map((o) => {
    const { ordTimeOffsetMinutes, symID, ...rest } = o
    const resolved: Record<string, unknown> = {
      ...rest,
      symbol: symbolByID(symID as string),
    }
    if (typeof ordTimeOffsetMinutes === 'number') {
      resolved.ordTime = formatOrdTime(ordTimeOffsetMinutes)
    }
    return resolved
  })
// `pnl`/`unrealizedPL`/`mtm` are display-only computed values a real host
// derives from the live price, so the fixture's schema doesn't carry them --
// synthesize them here, same as `symbol`.
export const seedPositions = () =>
  data().seedPositions.map((p) => ({
    ...p,
    symbol: symbolByID(p.symID as string),
    pnl: 250.0,
    unrealizedPL: 250.0,
    mtm: 250.0,
  }))
// Copy each row: nxtChartHost's placeOCOOrder pushes onto whatever this
// returns, which would otherwise mutate the cached fixture in place.
export const seedOcoOrders = () => data().seedOcoOrders.map((o) => ({ ...o }))

// -------------------------------------------------------------------------
// Native live generation, widened to every fixture symbol
// -------------------------------------------------------------------------

export function makeBars(
  count: number,
  intervalMs: number,
  to: number,
  symbolId: string,
): number[][] {
  const bars: number[][] = []
  for (let i = count - 1; i >= 0; i--) {
    const ts = to - i * intervalMs
    // Sampling the same continuous curve at each bar's start/end keeps
    // consecutive bars connected (this bar's close === the next bar's
    // open) without carrying mutable state across calls.
    const open = priceAt(symbolId, ts)
    const close = priceAt(symbolId, ts + intervalMs)
    const high = Math.max(open, close) + Math.random() * (open * 0.001)
    const low = Math.max(0.5, Math.min(open, close) - Math.random() * (open * 0.001))
    const volume = 1000 + Math.floor(Math.random() * 5000)
    bars.push([ts, open, high, low, close, volume])
  }
  return bars
}

/** One tick per symbol: every index (spot included), option, future, and equity -- matching MockChartDataSource.generateTicks()'s breadth. */
export function nextTicks(): Record<string, unknown>[] {
  const f = data()
  const ticks: Record<string, unknown>[] = []
  for (const index of f.indexSymbols) ticks.push(tickFor(index.id))
  for (const option of f.optionChain) ticks.push(tickFor(option.id))
  for (const future of f.futureSymbols) ticks.push(tickFor(future.id))
  for (const equity of f.equitySymbols) ticks.push(tickFor(equity.id))
  return ticks
}

function tickFor(symbolId: string): Record<string, unknown> {
  const base = data().basePrices[symbolId] ?? 22600
  // Anchored to the same curve `makeBars` samples for history (so ticks
  // never drift away from it), plus a small non-persisted jitter on top --
  // the curve's finest octave only refreshes every 20s, which read as
  // frozen from one 1s tick to the next.
  const anchor = priceAt(symbolId, Date.now())
  const price = Math.max(0.05, anchor + (Math.random() - 0.5) * (base * 0.0006))
  const ltp = Math.round(price * 100) / 100
  return {
    symbolId,
    ltp,
    ltq: 10 + Math.floor(Math.random() * 50),
    chng: Math.round((ltp - base) * 100) / 100,
    chngPer: Math.round(((ltp - base) / base) * 10000) / 100,
    ltt: Date.now(),
  }
}
