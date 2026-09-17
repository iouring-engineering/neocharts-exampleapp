// Mock `window.NxtChartHost` implementation for the JS-host demo. A real
// host replaces every mock value/handler below with real market and trade
// data -- the shape (getters, methods, `nxtchart:<name>` CustomEvents) is
// the actual contract `lib/src/channel/js_chart_interface.dart` reads.

import {
  atmSymbolsJson,
  chartTopOptionsJson,
  fetchAtmIvIntradayJson,
  fetchAtmStraddleIntradayJson,
  fetchOIAnalysisJson,
  fetchOIChangeJson,
  fetchOIJson,
  fetchOptionDetailsJson,
  fetchPcrIntradayJson,
  futureSymbolsJson,
  indexSymbolsJson,
  loadMockData,
  makeBars,
  marketTimingsJson,
  nextTicks,
  optionSymbolsJson,
  searchSymbols,
  seedOcoOrders,
  seedOrders,
  seedPositions,
  symbolInfoJson,
} from './mockDataSource'

export const THEME_STORAGE_KEY = 'nxtchart-demo-theme'

export interface NxtChartHost {
  readonly symbolInfo: string
  readonly underlyingSymbolInfo: string | null
  readonly optionSymbols: string
  readonly futureSymbols: string | null
  readonly indexSymbols: string | null
  readonly marketTimings: string
  readonly hasOCO: boolean
  readonly isMarketOrderSupported: boolean
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
  fundsData(): Promise<string>

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

function dispatch(eventName: string, detail: unknown): void {
  window.dispatchEvent(new CustomEvent(eventName, { detail: JSON.stringify(detail) }))
}

let orderCounter = 0
let ocoGroupCounter = 0
let alertCounter = 0
const subscribedSymbols = new Set<string>()
let orders: Record<string, unknown>[] = []
let positions: Record<string, unknown>[] = []
let ocoOrders: Record<string, unknown>[] = []
const alerts: Record<string, unknown>[] = []

export const nxtChartHost: NxtChartHost = {
  get symbolInfo() { return symbolInfoJson() },
  get underlyingSymbolInfo() { return '' },
  get optionSymbols() { return optionSymbolsJson() },
  get futureSymbols() { return futureSymbolsJson() },
  get indexSymbols() { return indexSymbolsJson() },
  get marketTimings() { return marketTimingsJson() },
  get hasOCO() { return true },
  get isMarketOrderSupported() { return true },
  get storageKey() { return 'js-host-demo' },
  get primaryColor() { return '#2EA7E0' },
  get onPrimaryColor() { return '#FFFFFF' },
  get forcedBrightness() {
    return localStorage.getItem(THEME_STORAGE_KEY) as 'light' | 'dark' | null
  },

  loadData(symbolId, _from, to, intervalSeconds, requiredBars) {
    return Promise.resolve(JSON.stringify(makeBars(requiredBars, intervalSeconds * 1000, to, symbolId)))
  },
  fetchOptionDetails() { return Promise.resolve(fetchOptionDetailsJson()) },
  chartTopOptions() { return Promise.resolve(chartTopOptionsJson()) },
  atmSymbols() { return Promise.resolve(atmSymbolsJson()) },
  searchSymbols(query) { return Promise.resolve(searchSymbols(query)) },
  fetchOIAnalysis() { return Promise.resolve(fetchOIAnalysisJson()) },
  fetchOIChange() { return Promise.resolve(fetchOIChangeJson()) },
  fetchOI() { return Promise.resolve(fetchOIJson()) },
  fetchPcrIntraday() { return Promise.resolve(fetchPcrIntradayJson()) },
  fetchAtmStraddleIntraday() { return Promise.resolve(fetchAtmStraddleIntradayJson()) },
  fetchAtmIvIntraday() { return Promise.resolve(fetchAtmIvIntradayJson()) },
  fundsData() { return Promise.resolve(JSON.stringify({ availableMargin: 347500.0, usedMargin: 152500.0 })) },

  placeOrder(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    orderCounter++
    orders.push({
      orderID: `ORD${String(orderCounter).padStart(3, '0')}`,
      symbolID: p.symID,
      avgPrice: p.price ?? 0,
      type: p.orderType ?? 'limit',
      netQty: p.qty ?? 0,
      fillQty: 0,
      orderAction: p.orderAction ?? 'buy',
    })
    dispatch('nxtchart:orders', orders)
    dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'Order placed' })
  },
  modifyOrder(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    const idx = orders.findIndex((o) => o.orderID === p.orderID)
    if (idx >= 0) {
      orders[idx] = { ...orders[idx], avgPrice: p.price ?? 0, netQty: p.qty ?? 0, type: p.orderType ?? 'limit', orderAction: p.orderAction ?? 'buy' }
      dispatch('nxtchart:orders', orders)
    }
  },
  cancelOrder(orderID) {
    orders = orders.filter((o) => o.orderID !== orderID)
    dispatch('nxtchart:orders', orders)
    dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'Order cancelled' })
  },
  placeOCOOrder(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    ocoGroupCounter++
    ocoOrders.push({ ...p, groupId: `OCO${String(ocoGroupCounter).padStart(3, '0')}` })
    dispatch('nxtchart:ocoOrders', ocoOrders)
    dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'OCO order placed' })
  },
  modifyOCOOrder(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    const idx = ocoOrders.findIndex((o) => o.groupId === p.groupId)
    if (idx >= 0) {
      ocoOrders[idx] = { ...ocoOrders[idx], ...p }
      dispatch('nxtchart:ocoOrders', ocoOrders)
    }
  },
  cancelOCOOrder(groupId) {
    ocoOrders = ocoOrders.filter((o) => o.groupId !== groupId)
    dispatch('nxtchart:ocoOrders', ocoOrders)
    dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'OCO order cancelled' })
  },
  groupAdjustOrders() {
    dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'Adjustment submitted' })
  },
  closeRequested() {
    location.href = location.pathname
  },
  createAlert(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    alertCounter++
    alerts.push({ ...p, alertId: `ALT${String(alertCounter).padStart(3, '0')}` })
    dispatch('nxtchart:alerts', alerts)
    dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'Alert created' })
  },
  modifyAlert(params) {
    const p = JSON.parse(params) as Record<string, unknown>
    const idx = alerts.findIndex((a) => a.alertId === p.alertId)
    if (idx >= 0) {
      alerts[idx] = { ...alerts[idx], ...p }
      dispatch('nxtchart:alerts', alerts)
    }
  },
  deleteAlert(alertId) {
    const idx = alerts.findIndex((a) => a.alertId === alertId)
    if (idx >= 0) {
      alerts.splice(idx, 1)
      dispatch('nxtchart:alerts', alerts)
      dispatch('nxtchart:actionFeedback', { type: 'positive', message: 'Alert deleted' })
    }
  },

  subscribeMarketData(symbols) {
    for (const id of JSON.parse(symbols) as string[]) subscribedSymbols.add(id)
  },
  unsubscribeMarketData() {
    subscribedSymbols.clear()
  },
}

export async function startMockFeeds(): Promise<void> {
  await loadMockData()
  orders = seedOrders()
  positions = seedPositions()
  ocoOrders = seedOcoOrders()
  // Seeded ids ("ORD001", "OCO001") live in the same numbering space as
  // generated ones -- start past them so the next placeOrder()/
  // placeOCOOrder() call can't mint a duplicate id (bug found while
  // transcribing this brief; same class of defect the Android/iOS sibling
  // tasks hit independently and fixed the same way).
  orderCounter = orders.length
  ocoGroupCounter = ocoOrders.length

  setInterval(() => {
    const ticks = nextTicks().filter((t) => subscribedSymbols.has(t.symbolId as string))
    if (ticks.length > 0) dispatch('nxtchart:marketData', ticks)
  }, 1000)

  setInterval(() => {
    dispatch('nxtchart:orders', orders)
    dispatch('nxtchart:positions', positions)
    dispatch('nxtchart:ocoOrders', ocoOrders)
  }, 2000)
}
