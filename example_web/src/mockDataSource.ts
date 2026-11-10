// apps/example_web/src/mockDataSource.ts
//
// Mock data for neoChartsHost.ts: reads the shared fixture (bundled as
// public/{symbols,oi,orders,positions,oco_orders,session}.json, symlinked
// from apps/mock/) and generates ticks and candles for every symbol in it.

interface SymbolInfo {
  id: string
  name: string
  segment?: string
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
  // equity). `optionChain`/`futures`/`underlyingOf` use this to scope
  // optionChain/futures to whichever underlying is being asked about.
  undID?: string
}

interface TopOption {
  id: string
  name: string
  optType: string
  exchange: string
}

interface UnderlyingAnalytics {
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
}

/** `session.json`'s shape; `init()` adds `initialSymbol` and `indexSymbols`. */
interface SessionFixture {
  storageKey: string
  initialSymbolId: string
  isMarketOrderSupported?: boolean
  productTypes?: Record<string, { values: string[]; default: string }>
  marketTimings: Record<string, unknown>
}

interface Fixture {
  optionChain: SymbolInfo[]
  futureSymbols: SymbolInfo[]
  indexSymbols: SymbolInfo[]
  equitySymbols: SymbolInfo[]
  basePrices: Record<string, number>
  topOptionsByUnderlying: Record<string, TopOption[]>
  seedOrders: Record<string, unknown>[]
  seedPositions: Record<string, unknown>[]
  seedOcoOrders: Record<string, unknown>[]
}

const REQUIRED_KEYS: (keyof Fixture)[] = [
  'optionChain',
  'futureSymbols',
  'indexSymbols',
  'equitySymbols',
  'basePrices',
  'topOptionsByUnderlying',
  'seedOrders',
  'seedPositions',
  'seedOcoOrders',
]

let fixture: Fixture | null = null
let analytics: Record<string, UnderlyingAnalytics> | null = null
let session: SessionFixture | null = null

const FIXTURE_FILES = ['symbols', 'orders', 'positions', 'oco_orders']

async function fetchJson<T>(name: string): Promise<T> {
  const response = await fetch(`/${name}.json`)
  // Check before parsing: a miss can come back as a real 404 whose body
  // still JSON-parses into something confusing, or as the SPA's index.html.
  if (!response.ok) {
    throw new Error(`Failed to load ${name}.json: HTTP ${response.status}`)
  }
  return (await response.json()) as T
}

export async function loadMockData(): Promise<void> {
  const json = {} as Fixture
  for (const name of FIXTURE_FILES) {
    Object.assign(json, await fetchJson<object>(name))
  }
  analytics = await fetchJson<Record<string, UnderlyingAnalytics>>('oi')
  session = await fetchJson<SessionFixture>('session')
  for (const key of REQUIRED_KEYS) {
    if (!(key in json)) throw new Error(`mock fixture is missing required key: ${key}`)
  }
  addWebOnlyBankex(json)
  fixture = json
}

// BANKEX (BSE bank index) with its option chain and future. The fixture is
// shared with the Android/iOS example apps, so it's layered on here instead
// of added to apps/mock/symbols.json -- only the web demo carries it.
// Built from the fixture's SENSEX entries (same exchange and expiry),
// re-based onto BANKEX's own level.
function addWebOnlyBankex(json: Fixture): void {
  const INDEX_ID = 'BANKEX'
  const TEMPLATE_ID = 'SENSEX'
  const indexLevel = 60000
  const scale = indexLevel / (json.basePrices[TEMPLATE_ID] ?? indexLevel)
  const rename = (v: string) => v.replace(TEMPLATE_ID, INDEX_ID)
  const rebase = (v: string, step = 1) =>
    String(Math.round((Number(v) * scale) / step) * step)

  const template = json.indexSymbols.find((s) => s.id === TEMPLATE_ID)
  if (!template || json.indexSymbols.some((s) => s.id === INDEX_ID)) return
  json.indexSymbols.push({ ...template, id: INDEX_ID, name: INDEX_ID })
  json.basePrices[INDEX_ID] = indexLevel

  const derive = (s: SymbolInfo): SymbolInfo => {
    const strike = s.strike === undefined ? undefined : rebase(s.strike, 100)
    return {
      ...s,
      id: rename(s.id).replace(s.strike ?? '', strike ?? ''),
      name: rename(s.name).replace(s.strike ?? '', strike ?? ''),
      undID: INDEX_ID,
      ...(strike === undefined ? {} : { strike }),
    }
  }
  const options = json.optionChain.filter((s) => s.undID === TEMPLATE_ID)
  const futures = json.futureSymbols.filter((s) => s.undID === TEMPLATE_ID)
  for (const src of [...options, ...futures]) {
    const dst = derive(src)
    json.basePrices[dst.id] = src.optType
      ? json.basePrices[src.id] ?? 0
      : indexLevel
    ;(src.optType ? json.optionChain : json.futureSymbols).push(dst)
  }
}

function analyticsFor(underlyingId: string): UnderlyingAnalytics | undefined {
  data()
  return analytics?.[underlyingId]
}

function data(): Fixture {
  if (!fixture) throw new Error('mockDataSource.loadMockData() must be awaited before use')
  return fixture
}

// Looks up any tradable instrument (future, option or equity) by id -- the
// index itself is deliberately excluded, since it isn't tradable (see
// seedOrders/seedPositions/placedOrder, which resolve each row's own symID
// through this instead of a single hardcoded symbol).
function symbolByID(symID: string): SymbolInfo {
  const found = [...data().futureSymbols, ...data().optionChain, ...data().equitySymbols].find((s) => s.id === symID)
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
export function formatOrdTime(offsetMinutes: number): string {
  const d = new Date(Date.now() - offsetMinutes * 60_000)
  return (
    `${pad2(d.getDate())}-${pad2(d.getMonth() + 1)}-${d.getFullYear()} ` +
    `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`
  )
}

// -------------------------------------------------------------------------
// Static fixture reads
// -------------------------------------------------------------------------

/**
 * The `init()` session: `session.json` plus the resolved initial symbol and
 * the index symbols.
 */
export function sessionJson(): string {
  const { indexSymbols } = data()
  const { initialSymbolId, ...rest } = session as SessionFixture
  const initialSymbol = anySymbolByID(initialSymbolId)
  if (!initialSymbol) throw new Error(`session.json: unknown initialSymbolId ${initialSymbolId}`)
  return JSON.stringify({ ...rest, initialSymbol, indexSymbols })
}

// The underlyings themselves -- entries with no `undID` of their own.
function underlyingCandidates(): SymbolInfo[] {
  return [...data().indexSymbols, ...data().equitySymbols]
}

// Any symbol in the fixture's full universe, by id -- unlike symbolByID
// (tradable derivatives only), this also matches an underlying itself.
function anySymbolByID(id: string): SymbolInfo | undefined {
  return [
    ...data().indexSymbols,
    ...data().equitySymbols,
    ...data().optionChain,
    ...data().futureSymbols,
  ].find((s) => s.id === id)
}

/** One symbol of the fixture's universe by id (`{id}` if unknown). */
export function symbolOrStub(id: string): SymbolInfo {
  return anySymbolByID(id) ?? ({ id } as SymbolInfo)
}

/** Total: an underlying (or an unknown id) resolves to itself. */
export function underlyingOfJson(symbolId: string): string {
  const symbol = symbolOrStub(symbolId)
  const underlying = symbol.undID
    ? underlyingCandidates().find((s) => s.id === symbol.undID)
    : undefined
  return JSON.stringify(underlying ?? symbol)
}

export function optionChainJson(underlyingId: string): string {
  return JSON.stringify(data().optionChain.filter((s) => s.undID === underlyingId))
}

export function futuresJson(underlyingId: string): string {
  return JSON.stringify(data().futureSymbols.filter((s) => s.undID === underlyingId))
}

export function topOptionsJson(underlyingId: string): string {
  return JSON.stringify(data().topOptionsByUnderlying[underlyingId] ?? [])
}

// -------------------------------------------------------------------------
// Margin and brokerage previews (the formulas every example app shares)
// -------------------------------------------------------------------------

// Malformed request JSON is "unpriceable", like any other bad input.
function parseRequest(request: string): Record<string, unknown> | null {
  try {
    return JSON.parse(request) as Record<string, unknown>
  } catch {
    return null
  }
}

/** Full order value, or 20% of it for intraday; null when unpriceable. */
export function marginForJson(request: string): string | null {
  const r = parseRequest(request)
  if (!r) return null
  const symbol = anySymbolByID(String(r.symbolId))
  const lots = Number(r.lots)
  const ltp = Number(r.ltp)
  if (!symbol || !(lots > 0) || !(ltp > 0)) return null
  const share = r.productType === 'intraday' ? 0.2 : 1.0
  return String(lots * (symbol.lotSize ?? 1) * ltp * share)
}

/** 0.03% of the order value, capped at 20; null when unpriceable. */
export function brokerageForJson(request: string): string | null {
  const r = parseRequest(request)
  if (!r) return null
  const quantity = Number(r.quantity)
  const price = Number(r.price)
  if (!anySymbolByID(String(r.symbolId)) || !(quantity > 0) || !(price > 0)) return null
  return String(Math.min(quantity * price * 0.0003, 20))
}

export function searchSymbols(query: string): string {
  const keyword = query.trim().toLowerCase()
  if (!keyword) return JSON.stringify([])

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

export function oiAnalysisJson(underlyingId: string): string | null {
  const a = analyticsFor(underlyingId)
  return a ? JSON.stringify(a.oi.analysisAroundAtm) : null
}
export function oiChangeJson(underlyingId: string): string | null {
  const a = analyticsFor(underlyingId)
  return a ? JSON.stringify(a.oi.changeByStrike) : null
}
export function oiJson(underlyingId: string): string | null {
  const a = analyticsFor(underlyingId)
  return a ? JSON.stringify(a.oi.byStrike) : null
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

export function pcrIntradayJson(underlyingId: string): string | null {
  const a = analyticsFor(underlyingId)
  return a ? JSON.stringify(withResolvedTimes(a.pcrIntraday)) : null
}
export function atmIvIntradayJson(underlyingId: string): string | null {
  const a = analyticsFor(underlyingId)
  return a ? JSON.stringify(withResolvedTimes(a.atmIvIntraday)) : null
}
export function atmStraddleIntradayJson(underlyingId: string): string | null {
  const a = analyticsFor(underlyingId)
  if (!a) return null
  const resolved: Record<string, unknown> = {}
  for (const [expiry, rows] of Object.entries(a.atmStraddleIntraday)) {
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
// A just-placed order, shaped like a seedOrders row (`Order.fromJson` reads
// `symbol`, `productType`, `orderStatus`, `ordTime`) from `placeOrder`'s
// OrderParams JSON.
export const placedOrder = (orderID: string, p: Record<string, unknown>) => ({
  orderID,
  symbol: symbolByID(p.symID as string),
  type: p.orderType ?? 'limit',
  orderAction: p.orderAction ?? 'buy',
  productType: p.productType ?? 'normal',
  avgPrice: p.price ?? 0,
  price: p.orderType === 'market' ? priceOf(p.symID as string) : (p.price ?? 0),
  netQty: p.qty ?? 0,
  fillQty: 0,
  orderStatus: 'open',
  triggerPrice: p.triggerPrice ?? 0,
  ordTime: formatOrdTime(0),
})
// `pnl`/`unrealizedPL`/`mtm` are display-only values a real host derives
// from the live price, so the fixture doesn't carry them; the host fills
// them in per tick (see `positionPnl`).
export const seedPositions = () =>
  data().seedPositions.map((p) => ({
    ...p,
    symbol: symbolByID(p.symID as string),
    pnl: 0,
    unrealizedPL: 0,
    mtm: 0,
  }))

/** The current mock price of a symbol: the same curve ticks and bars use. */
export function priceOf(symbolId: string): number {
  return priceAt(symbolId, Date.now())
}

/** Unrealised P&L of a position row at the current mock price. */
export function positionPnl(position: Record<string, unknown>): number {
  const diff = priceOf(position.symID as string) - Number(position.avgPrice)
  return Math.round(diff * Number(position.netQty) * 100) / 100
}
// Copy each row: the host's placeOcoOrder pushes onto whatever this
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
  // Bar times sit on the interval grid, so repeated loads line up.
  const last = Math.floor(to / intervalMs) * intervalMs
  for (let i = count - 1; i >= 0; i--) {
    const ts = last - i * intervalMs
    // Sampling the same continuous curve at each bar's start/end keeps
    // consecutive bars connected (this bar's close === the next bar's
    // open) without carrying mutable state across calls. High and low are
    // the extremes of the curve inside the bar; volume is seeded per bar.
    const open = priceAt(symbolId, ts)
    const close = priceAt(symbolId, ts + intervalMs)
    let high = Math.max(open, close)
    let low = Math.min(open, close)
    for (const part of [0.25, 0.5, 0.75]) {
      const p = priceAt(symbolId, ts + intervalMs * part)
      high = Math.max(high, p)
      low = Math.min(low, p)
    }
    const volume = 1000 + Math.floor(seededUnit(`${symbolId}:vol:${ts}`) * 5000)
    bars.push([ts, open, high, low, close, volume])
  }
  return bars
}

/** One tick, with its depth fields, per subscribed symbol id. */
export function nextTicks(symbolIds: Iterable<string>): Record<string, unknown>[] {
  return [...symbolIds].map((id) => ({ ...tickFor(id), ...depthFor(id) }))
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
    ...optionOiFields(symbolId),
  }
}

// -------------------------------------------------------------------------
// Market depth (order book) -- 5 bid/ask levels plus day statistics
// -------------------------------------------------------------------------

interface DayStats {
  open: number
  high: number
  low: number
  volume: number
  turnover: number
}

// Day high/low/volume only ever widen/accumulate, so they live across
// snapshots (unlike the book itself, which is regenerated each time).
const dayStats = new Map<string, DayStats>()

const DEPTH_LEVELS = 5

function tickSizeFor(symbolId: string): number {
  const f = data()
  const all = [...f.indexSymbols, ...f.optionChain, ...f.futureSymbols, ...f.equitySymbols]
  return all.find((s) => s.id === symbolId)?.tickSize || 0.05
}

function roundToTick(value: number, tick: number): number {
  return Math.round(Math.round(value / tick) * tick * 1e4) / 1e4
}

function depthSide(
  start: number,
  tick: number,
  direction: 1 | -1,
): { price: number; qty: number; orders: number }[] {
  const levels = []
  for (let i = 0; i < DEPTH_LEVELS; i++) {
    // Resting size thins out away from the touch, like a real book.
    const qty = Math.round((1300 - i * 250) * (0.6 + Math.random() * 0.8))
    levels.push({
      price: roundToTick(start + direction * i * tick, tick),
      qty,
      orders: Math.max(1, Math.round(qty / 180 + Math.random() * 2)),
    })
  }
  return levels
}

/** Order-book fields for one symbol, merged onto its `marketDataStreamer`
 * tick. Each call is an independent full snapshot (no deltas); `symbolId`,
 * `vol` and `ltt` are left to the tick itself. */
function depthFor(symbolId: string): Record<string, unknown> {
  const base = data().basePrices[symbolId] ?? 22600
  const tick = tickSizeFor(symbolId)
  const ltp = roundToTick(
    Math.max(tick, priceAt(symbolId, Date.now()) + (Math.random() - 0.5) * base * 0.0006),
    tick,
  )

  let stats = dayStats.get(symbolId)
  if (!stats) {
    const open = roundToTick(base * (1 + (seededUnit(`${symbolId}:open`) - 0.5) * 0.01), tick)
    stats = { open, high: open, low: open, volume: 1_000_000 * (1 + seededUnit(`${symbolId}:vol`)), turnover: 0 }
    stats.turnover = stats.volume * open
    dayStats.set(symbolId, stats)
  }
  stats.high = Math.max(stats.high, ltp)
  stats.low = Math.min(stats.low, ltp)
  const ltq = 1 + Math.floor(Math.random() * 100)
  stats.volume += ltq
  stats.turnover += ltq * ltp

  const bids = depthSide(ltp - tick, tick, -1)
  const asks = depthSide(ltp + tick, tick, 1)
  // Totals cover the whole book, not just the five visible levels.
  const bookTotal = (levels: { qty: number }[]) =>
    Math.round(levels.reduce((sum, l) => sum + l.qty, 0) * (1.4 + Math.random() * 0.4))

  return {
    bids,
    asks,
    totalBuyQty: bookTotal(bids),
    totalSellQty: bookTotal(asks),
    open: stats.open,
    high: stats.high,
    low: stats.low,
    prevClose: base,
    avgTradePrice: roundToTick(stats.turnover / stats.volume, tick),
    ltq,
  }
}

// Open interest / volume for an option tick, so the option chain's OI
// columns, OI bars and support/resistance markers have something to show.
// Base OI comes from the fixture's per-strike table (strikes outside it
// fall back to a bell shape around the ATM), with a little jitter per tick.
// Every third strike is given a negative OI change so both colours appear.
// Non-option symbols get no extra fields.
function optionOiFields(symbolId: string): Record<string, unknown> {
  const option = data().optionChain.find((o) => o.id === symbolId)
  if (!option?.strike || !option.optType) return {}

  const strike = Number(option.strike)
  const side = option.optType === 'CE' ? 'calls' : 'puts'
  const oi = analyticsFor(option.undID ?? '')?.oi
  const byStrike = oi?.byStrike ?? { calls: {}, puts: {} }
  const changeByStrike = oi?.changeByStrike ?? { calls: {}, puts: {} }
  const atm = data().basePrices[option.undID ?? ''] ?? 22600
  const fallback = Math.round(
    120_000 * Math.exp(-(((strike - atm) / 400) ** 2)) + 20_000,
  )
  const baseOi = byStrike[side][option.strike] ?? fallback
  const liveOi = Math.round(baseOi * (1 + (Math.random() - 0.5) * 0.01))
  const magnitude = changeByStrike[side][option.strike] ?? Math.round(baseOi * 0.03)
  const oiChng = (strike / 50) % 3 === 0 ? -magnitude : magnitude
  const prevOi = liveOi - oiChng

  return {
    OI: liveOi,
    oiChng,
    oiChngPer: prevOi > 0 ? Math.round((oiChng / prevOi) * 10000) / 100 : 0,
    vol: Math.round(baseOi * 0.4 * (1 + Math.random() * 0.05)),
  }
}
