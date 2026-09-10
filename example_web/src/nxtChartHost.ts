// Mock `window.NxtChartHost` implementation for the JS-host demo. A real
// host replaces every mock value/handler below with real market and trade
// data -- the shape (getters, methods, `nxtchart:<name>` CustomEvents) is
// the actual contract `lib/src/channel/js_chart_interface.dart` reads.

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

export interface NxtChartHost {
  readonly symbolInfo: string
  readonly underlyingSymbolInfo: string | null
  readonly optionSymbols: string
  readonly futureSymbols: string | null
  readonly indexSymbols: string | null
  readonly marketTiming: string
  readonly hasOCO: boolean
  readonly storageKey: string
  readonly primaryColor: string | null
  readonly onPrimaryColor: string | null
  readonly forcedBrightness: 'light' | 'dark' | null

  loadData(
    symbolId: string,
    from: number,
    to: number,
    intervalSeconds: number,
    requiredBars: number,
  ): Promise<string>
  fetchOptionDetails(underlyingSymbolId: string): Promise<string>
  chartTopOptions(): Promise<string>
  atmSymbols(): Promise<string | null>
  searchSymbols(query: string): Promise<string>
  fetchOIAnalysis(
    underlyingSymbolId: string,
    expiry: string,
    timeFrom: number,
    timeTo: number,
  ): Promise<string | null>
  fetchOIChange(
    underlyingSymbolId: string,
    expiries: string[],
    timeFrom: number,
    timeTo: number,
  ): Promise<string | null>
  fetchOI(underlyingSymbolId: string, expiries: string[]): Promise<string | null>
  fetchPcrIntraday(): Promise<string>
  fetchAtmStraddleIntraday(): Promise<string>
  fetchAtmIvIntraday(): Promise<string>

  placeOrder(params: string): void
  modifyOrder(params: string): void
  cancelOrder(orderID: string): void
  placeOCOOrder(params: string): void
  modifyOCOOrder(params: string): void
  cancelOCOOrder(groupId: string): void
  groupAdjustOrders(params: string): void
  closeRequested(): void
  modifyAlert(params: string): void
  createAlert(params: string): void
  deleteAlert(alertId: string): void

  subscribeMarketData(symbols: string): void
  unsubscribeMarketData(): void
}

declare global {
  interface Window {
    NxtChartHost: NxtChartHost
  }
}

const LOT_SIZE = 50
const PRECISION = 2
const TICK_SIZE = 0.05
export const THEME_STORAGE_KEY = 'nxtchart-demo-theme'

const symbolInfoObj: SymbolInfo = {
  id: 'NIFTY',
  name: 'NIFTY 50',
  lotSize: LOT_SIZE,
  precision: PRECISION,
  tickSize: TICK_SIZE,
}
const symbolInfoJson = JSON.stringify(symbolInfoObj)

const marketTimingJson = JSON.stringify({
  timezone: 'Asia/Kolkata',
  sessions: [
    ['0915-1530'], // Monday
    ['0915-1530'], // Tuesday
    ['0915-1530'], // Wednesday
    ['0915-1530'], // Thursday
    ['0915-1530'], // Friday
    [], // Saturday
    [], // Sunday
  ],
  holidays: [] as string[],
  special: {} as Record<string, string[]>,
})

const MONTH_CODES = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
]

function pad2(n: number): string {
  return String(n).padStart(2, '0')
}

function nextThursdays(count: number): Date[] {
  const dates: Date[] = []
  let day = new Date()
  while (dates.length < count) {
    day = new Date(day.getTime() + 86400000)
    if (day.getDay() === 4) dates.push(new Date(day))
  }
  return dates
}

// "DD-MM-YYYY HH:mm:ss" — matches lib/src/extensions/string_x.dart's
// formatTime(), not ISO-8601 (see trade_interface.dart's ordTime doc).
function formatOrdTime(d: Date): string {
  return (
    `${pad2(d.getDate())}-${pad2(d.getMonth() + 1)}-${d.getFullYear()} ` +
    `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`
  )
}

function expiryStr(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}

function expiryId(d: Date): string {
  return `${pad2(d.getDate())}${MONTH_CODES[d.getMonth()]}${d.getFullYear() % 100}`
}

function makeOptionContract(expiry: Date, strike: number, optType: 'CE' | 'PE'): SymbolInfo {
  return {
    id: `NIFTY${expiryId(expiry)}${strike}${optType}`,
    name: `NIFTY ${strike} ${optType}`,
    precision: PRECISION,
    lotSize: LOT_SIZE,
    tickSize: TICK_SIZE,
    expiry: expiryStr(expiry),
    exchange: 'NSE',
    strike: String(strike),
    optType,
    weekly: 'N',
  }
}

const expiries = nextThursdays(3)
const strikes: number[] = []
for (let s = 21000; s <= 24000; s += 100) strikes.push(s)

const optionChain: SymbolInfo[] = []
for (const expiry of expiries) {
  for (const strike of strikes) {
    optionChain.push(makeOptionContract(expiry, strike, 'CE'))
    optionChain.push(makeOptionContract(expiry, strike, 'PE'))
  }
}
const optionSymbolsJson = JSON.stringify(optionChain)

const nearestExpiry = expiries[0]
const atmStrike = 22500
const atmCall = makeOptionContract(nearestExpiry, atmStrike, 'CE')
const atmPut = makeOptionContract(nearestExpiry, atmStrike, 'PE')
const atmSymbolsJson = JSON.stringify([atmCall, atmPut])

const topOptionsJson = JSON.stringify([
  { symId: makeOptionContract(nearestExpiry, 22600, 'CE').id, name: 'NIFTY 22600 CE', optType: 'CE', exchange: 'NSE' },
  { symId: makeOptionContract(nearestExpiry, 22400, 'PE').id, name: 'NIFTY 22400 PE', optType: 'PE', exchange: 'NSE' },
  { symId: atmCall.id, name: atmCall.name, optType: 'CE', exchange: 'NSE' },
  { symId: atmPut.id, name: atmPut.name, optType: 'PE', exchange: 'NSE' },
])

function fetchOptionDetailsFor(): string {
  return JSON.stringify([symbolInfoObj, ...optionChain])
}

let price = 22500
let orderCounter = 2

// Seeded so the orders/positions/OCO streams have real content from the
// start, not just after a user action.
const orders: Record<string, unknown>[] = [
  {
    orderID: 'ORD001',
    type: 'limit',
    orderAction: 'buy',
    productType: 'intraday',
    avgPrice: 22400,
    netQty: 50,
    fillQty: 0,
    ordTime: formatOrdTime(new Date()),
    orderStatus: 'open',
    triggerPrice: 0,
    symbol: symbolInfoObj,
  },
]

const positions = [
  {
    symID: 'NIFTY',
    displayName: 'NIFTY 50',
    netQty: 50,
    avgPrice: 22450.0,
    netOrgAvgPrice: 22450.0,
    pnl: 250.0,
    realizedPnl: 0.0,
    realizedOrgPnl: 0.0,
    unrealizedPL: 250.0,
    mtm: 250.0,
    multiplier: 1.0,
    priceFactor: 1.0,
    productType: 'intraday',
    symbol: symbolInfoObj,
  },
]

const ocoOrders = [
  {
    groupId: 'OCO001',
    symID: 'NIFTY',
    name: 'NIFTY 50',
    exchange: 'NSE',
    side: 'sell',
    productType: 'intraday',
    stopLoss: { type: 'stopLoss', side: 'sell', triggerPrice: 22300, qty: 50, price: 22290, fillQty: 0 },
    target: { type: 'limit', side: 'sell', triggerPrice: 22700, qty: 50, price: 22700, fillQty: 0 },
  },
]

function makeBars(count: number, intervalMs: number, to: number): number[][] {
  const bars: number[][] = []
  let p = price
  for (let i = count - 1; i >= 0; i--) {
    const ts = to - i * intervalMs
    const open = p
    const change = (Math.random() - 0.48) * 50
    const close = Math.max(18000, Math.min(28000, open + change))
    const high = Math.max(open, close) + Math.random() * 20
    const low = Math.min(open, close) - Math.random() * 20
    const volume = 1000 + Math.floor(Math.random() * 5000)
    bars.push([ts, open, high, low, close, volume])
    p = close
  }
  price = p
  return bars
}

function dispatch(name: string, detail: unknown): void {
  window.dispatchEvent(new CustomEvent(name, { detail: JSON.stringify(detail) }))
}

/** Starts the demo's background tick/seed-data timers. Call once. */
export function startMockFeeds(): void {
  // Live tick, once a second.
  setInterval(() => {
    price += (Math.random() - 0.48) * 10
    price = Math.max(18000, Math.min(28000, price))
    const ltp = Math.round(price * 100) / 100
    dispatch('nxtchart:marketData', [
      {
        symbolId: 'NIFTY',
        ltp,
        ltq: 10 + Math.floor(Math.random() * 50),
        chng: Math.round((ltp - 22500) * 100) / 100,
        chngPer: Math.round(((ltp - 22500) / 22500) * 10000) / 100,
        ltt: Date.now(),
      },
    ])
  }, 1000)

  // Orders/positions/OCO streams only reach a listener once the Flutter
  // side has actually subscribed (broadcast streams don't replay past
  // events). Re-dispatching every couple seconds means whichever bloc
  // subscribes late still gets seeded data on the next tick, instead of
  // depending on a one-shot dispatch racing app startup.
  setInterval(() => {
    dispatch('nxtchart:orders', orders)
    dispatch('nxtchart:positions', positions)
    dispatch('nxtchart:ocoOrders', ocoOrders)
  }, 2000)
}

export const nxtChartHost: NxtChartHost = {
  get symbolInfo() { return symbolInfoJson },
  get underlyingSymbolInfo() { return null },
  get optionSymbols() { return optionSymbolsJson },
  get futureSymbols() { return null },
  get indexSymbols() { return null },
  get marketTiming() { return marketTimingJson },
  get hasOCO() { return true },
  get storageKey() { return 'js-host-demo' },
  // Optional host branding — any real host can set its own colors here.
  get primaryColor() { return '#2EA7E0' },
  get onPrimaryColor() { return '#FFFFFF' },
  // The demo toolbar's theme button writes this to localStorage and
  // reloads; a real host just returns its own current theme.
  get forcedBrightness() {
    return localStorage.getItem(THEME_STORAGE_KEY) as 'light' | 'dark' | null
  },

  loadData(_symbolId, _from, to, intervalSeconds, requiredBars) {
    return Promise.resolve(JSON.stringify(makeBars(requiredBars, intervalSeconds * 1000, to)))
  },
  fetchOptionDetails() {
    return Promise.resolve(fetchOptionDetailsFor())
  },
  chartTopOptions() {
    return Promise.resolve(topOptionsJson)
  },
  atmSymbols() {
    return Promise.resolve(atmSymbolsJson)
  },
  searchSymbols(query) {
    const keyword = query.trim().toLowerCase()
    const matches = keyword
      ? optionChain.filter(
          (s) => s.name.toLowerCase().includes(keyword) || s.id.toLowerCase().includes(keyword),
        )
      : []
    return Promise.resolve(JSON.stringify(matches))
  },
  // Not seeded with mock data in this demo — a real host resolves these
  // from its own OI/PCR/IV data source.
  fetchOIAnalysis() { return Promise.resolve(null) },
  fetchOIChange() { return Promise.resolve(null) },
  fetchOI() { return Promise.resolve(null) },
  fetchPcrIntraday() { return Promise.resolve('[]') },
  fetchAtmStraddleIntraday() { return Promise.resolve('{}') },
  fetchAtmIvIntraday() { return Promise.resolve('[]') },

  placeOrder(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    orderCounter++
    const order = {
      orderID: `ORD${String(orderCounter).padStart(3, '0')}`,
      type: p.orderType,
      orderAction: p.orderAction,
      productType: p.productType,
      avgPrice: p.price,
      netQty: p.qty,
      fillQty: 0,
      ordTime: formatOrdTime(new Date()),
      orderStatus: 'open',
      triggerPrice: p.triggerPrice ?? 0,
      symbol: { id: p.symID, name: p.symID, lotSize: LOT_SIZE, precision: PRECISION, tickSize: TICK_SIZE },
    }
    orders.push(order)
    dispatch('nxtchart:orders', orders)
    dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'Order placed' })
  },
  modifyOrder(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    const idx = orders.findIndex((o) => o.orderID === p.orderID)
    if (idx !== -1) {
      orders[idx] = {
        ...orders[idx],
        avgPrice: p.price,
        netQty: p.qty,
        type: p.orderType,
        orderAction: p.orderAction,
      }
      dispatch('nxtchart:orders', orders)
    }
  },
  cancelOrder(orderID) {
    const idx = orders.findIndex((o) => o.orderID === orderID)
    if (idx !== -1) orders.splice(idx, 1)
    dispatch('nxtchart:orders', orders)
    dispatch('nxtchart:actionFeedback', { type: 'negative', message: 'Order cancelled' })
  },
  placeOCOOrder() {},
  modifyOCOOrder() {},
  cancelOCOOrder() {},
  groupAdjustOrders() {},
  closeRequested() {
    location.hash = ''
    location.reload()
  },
  modifyAlert() {},
  createAlert() {},
  deleteAlert() {},

  subscribeMarketData() {},
  unsubscribeMarketData() {},
}
