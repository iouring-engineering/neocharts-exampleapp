// apps/example_web/src/mockDataSource.ts
//
// Reads the shared fixture (bundled as public/{symbols,oi,orders,positions,
// oco_orders}.json, symlinked from apps/mock/) and serves it as plain reads,
// plus this platform's own native live-tick and candle-walk generation
// widened to every symbol in the fixture.

interface SymbolInfo {
  id: string
  name: string
  lotSize: number
  precision: number
  tickSize: number
  exchange?: string
  expiry?: string
  strike?: string
  optType?: 'CE' | 'PE'
  weekly?: 'Y' | 'N'
}

interface Fixture {
  niftySymbol: SymbolInfo
  optionChain: SymbolInfo[]
  futureSymbols: SymbolInfo[]
  indexSymbols: SymbolInfo[]
  basePrices: Record<string, number>
  topOptionsByVolume: { symId: string; name: string; optType: string; exchange: string }[]
  oi: {
    byStrike: { calls: Record<string, number>; puts: Record<string, number> }
    changeByStrike: { calls: Record<string, number>; puts: Record<string, number> }
    analysisAroundAtm: {
      calls: Record<string, { oi: number; oiChg: number; prevOi: number }>
      puts: Record<string, { oi: number; oiChg: number; prevOi: number }>
    }
  }
  pcrIntraday: { offsetMinutes: number; price: number; pcr: Record<string, number> }[]
  atmStraddleIntraday: Record<string, { offsetMinutes: number; atmStraddlePrice: number }[]>
  atmIvIntraday: { offsetMinutes: number; atmIv: number }[]
  seedOrders: Record<string, unknown>[]
  seedPositions: Record<string, unknown>[]
  seedOcoOrders: Record<string, unknown>[]
}

const REQUIRED_KEYS: (keyof Fixture)[] = [
  'niftySymbol', 'optionChain', 'futureSymbols', 'indexSymbols', 'basePrices',
  'topOptionsByVolume', 'oi', 'pcrIntraday', 'atmStraddleIntraday',
  'atmIvIntraday', 'seedOrders', 'seedPositions', 'seedOcoOrders',
]

let fixture: Fixture | null = null
const livePrices = new Map<string, number>()

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

function priceFor(symbolId: string): number {
  let price = livePrices.get(symbolId)
  if (price === undefined) {
    price = data().basePrices[symbolId] ?? 22600
    livePrices.set(symbolId, price)
  }
  return price
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

export function symbolInfoJson(): string { return JSON.stringify(data().niftySymbol) }
export function optionSymbolsJson(): string { return JSON.stringify(data().optionChain) }
// Unlike the bare chain `optionSymbols` returns, `fetchOptionDetails` requires
// the underlying's own symbol info as the first element (the one entry without
// an `optType`) so the chart can resolve the spot price -- see
// MKTDataInterface.fetchOptionDetails.
export function fetchOptionDetailsJson(): string {
  return JSON.stringify([data().niftySymbol, ...data().optionChain])
}
export function futureSymbolsJson(): string { return JSON.stringify(data().futureSymbols) }
export function indexSymbolsJson(): string { return JSON.stringify(data().indexSymbols) }

// `sessions` is an array indexed by weekday (0 = Monday ... 6 = Sunday), each
// entry an array of "HHMM-HHMM" ranges and an empty array for a non-trading
// day -- see MarketTiming.fromJson in lib/src/models/market_timing.dart.
// Open every hour of every day -- a real exchange trades ~6h on weekdays
// only, but this is a demo: it should show live movement no matter when
// someone runs it, not just 09:15-15:30 IST on a weekday.
export function marketTimingJson(): string {
  const sessions = Array.from({ length: 7 }, () => ['0000-2359'])
  return JSON.stringify({ timezone: 'Asia/Kolkata', sessions, holidays: [], special: {} })
}

export function chartTopOptionsJson(): string { return JSON.stringify(data().topOptionsByVolume) }

export function atmSymbolsJson(): string {
  const chain = data().optionChain
  const atmStrike = chain.reduce((closest, opt) => {
    const strike = Number(opt.strike)
    return Math.abs(strike - (data().basePrices.NIFTY ?? 22600)) <
      Math.abs(Number(closest?.strike ?? 0) - (data().basePrices.NIFTY ?? 22600))
      ? opt
      : closest
  }, chain[0])
  const strike = atmStrike?.strike
  const call = chain.find((o) => o.strike === strike && o.optType === 'CE')
  const put = chain.find((o) => o.strike === strike && o.optType === 'PE')
  // A JSON array of [ceSymbolInfo, peSymbolInfo] -- see
  // MKTDataInterface.atmSymbols in lib/src/interface/market_data_interface.dart.
  return JSON.stringify([call, put])
}

export function searchSymbols(query: string): string {
  const keyword = query.trim().toLowerCase()
  const matches = keyword
    ? data().optionChain.filter(
        (s) => s.name.toLowerCase().includes(keyword) || s.id.toLowerCase().includes(keyword)
      )
    : []
  return JSON.stringify(matches)
}

export function fetchOIAnalysisJson(): string { return JSON.stringify(data().oi.analysisAroundAtm) }
export function fetchOIChangeJson(): string { return JSON.stringify(data().oi.changeByStrike) }
export function fetchOIJson(): string { return JSON.stringify(data().oi.byStrike) }

function withResolvedTimes<T extends { offsetMinutes: number }>(rows: T[]): (Omit<T, 'offsetMinutes'> & { time: number })[] {
  const now = Date.now()
  return rows.map(({ offsetMinutes, ...rest }) => ({ ...rest, time: now - offsetMinutes * 60_000 }))
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
    const { ordTimeOffsetMinutes, ...rest } = o
    // The index itself isn't tradable -- seed orders/positions/OCO orders
    // all trade its front-month future instead (see also seedPositions and
    // oco_orders.json's symID/name).
    const resolved: Record<string, unknown> = { ...rest, symbol: data().futureSymbols[0] }
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
    symbol: data().futureSymbols[0],
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

export function makeBars(count: number, intervalMs: number, to: number, symbolId: string): number[][] {
  const bars: number[][] = []
  let p = priceFor(symbolId)
  for (let i = count - 1; i >= 0; i--) {
    const ts = to - i * intervalMs
    const open = p
    const change = (Math.random() - 0.48) * (open * 0.002)
    const close = Math.max(1, open + change)
    const high = Math.max(open, close) + Math.random() * (open * 0.001)
    const low = Math.max(0.5, Math.min(open, close) - Math.random() * (open * 0.001))
    const volume = 1000 + Math.floor(Math.random() * 5000)
    bars.push([ts, open, high, low, close, volume])
    p = close
  }
  livePrices.set(symbolId, p)
  return bars
}

/** One tick per symbol: spot, then every option, then every future -- matching MockChartDataSource.generateTicks()'s breadth. */
export function nextTicks(): Record<string, unknown>[] {
  const f = data()
  const ticks: Record<string, unknown>[] = [tickFor(f.niftySymbol.id)]
  for (const option of f.optionChain) ticks.push(tickFor(option.id))
  for (const future of f.futureSymbols) ticks.push(tickFor(future.id))
  return ticks
}

function tickFor(symbolId: string): Record<string, unknown> {
  const base = data().basePrices[symbolId] ?? 22600
  let price = priceFor(symbolId)
  price += (Math.random() - 0.48) * (base * 0.001)
  price = Math.max(0.05, price)
  livePrices.set(symbolId, price)
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
