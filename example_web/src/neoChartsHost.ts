// Mock NeoCharts host for the web example. A real host replaces every mock
// value/handler below with real market and trade data -- the shape (the
// methods, and `neocharts:<name>` CustomEvents dispatched on the mount
// element) is the contract in neocharts-host.d.ts.

import type { NeoChartsHostObject, NeoChartsTheme } from './neocharts-host'
import {
  atmIvIntradayJson,
  atmStraddleIntradayJson,
  brokerageForJson,
  formatOrdTime,
  futuresJson,
  loadMockData,
  makeBars,
  marginForJson,
  nextTicks,
  oiAnalysisJson,
  oiChangeJson,
  oiJson,
  optionChainJson,
  pcrIntradayJson,
  placedOrder,
  positionPnl,
  priceOf,
  searchSymbols,
  seedOcoOrders,
  seedOrders,
  seedPositions,
  sessionJson,
  symbolOrStub,
  topOptionsJson,
  underlyingOfJson,
} from './mockDataSource'

export const THEME_STORAGE_KEY = 'nxtchart-demo-theme'

/** The mount theme: the landing page's saved brightness plus demo brand colors. */
export function currentTheme(): NeoChartsTheme {
  let stored: string | null = null
  try {
    stored = localStorage.getItem(THEME_STORAGE_KEY)
  } catch {
    // Storage blocked: follow the system.
  }
  // Demo brand colors for both modes -- see the theming docs for all 14 tokens.
  const demo = {
    primary: '#7B1FA2',
    onPrimary: '#FFFFFF',
    bullish: '#26A69A',
    bearish: '#EF5350',
  }
  return {
    brightness: stored === 'light' || stored === 'dark' ? stored : null,
    colors: { light: demo, dark: demo },
  }
}

/** Resolves once the fixture is loaded -- `createHost` needs it. */
export const mockDataReady: Promise<void> = loadMockData().catch((err) => {
  console.error('Failed to load the mock fixture:', err)
})

type Row = Record<string, unknown>

/**
 * A fresh host for one mount, plus `stop()`, which clears its timers.
 * Events go to `element`; call `stop()` when the chart unmounts.
 */
export function createHost(element: HTMLElement): {
  host: NeoChartsHostObject
  stop(): void
} {
  let stopped = false
  const dispatch = (name: string, detail: unknown): void => {
    if (stopped) return
    element.dispatchEvent(
      new CustomEvent(`neocharts:${name}`, { detail: JSON.stringify(detail) }),
    )
  }
  const feedback = (message: string, type = 'positive'): void =>
    dispatch('actionFeedback', { type, message })

  let orders: Row[] = seedOrders()
  let positions: Row[] = seedPositions()
  let ocoOrders: Row[] = seedOcoOrders()
  let alerts: Row[] = []
  // Seeded ids ("ORD001", "OCO001") share a numbering space with generated
  // ones -- start past them so a new id can't duplicate a seeded one.
  let orderCounter = orders.length
  let ocoGroupCounter = ocoOrders.length
  let alertCounter = 0
  let subscribed: string[] = []

  const parse = (json: string): Row => JSON.parse(json) as Row
  const idOf = (n: number, prefix: string): string =>
    `${prefix}${String(n).padStart(3, '0')}`

  const num = (v: unknown): number => Number(v) || 0
  const isBuy = (action: unknown): boolean => String(action).toLowerCase() === 'buy'
  const sameLine = (p: Row, symbolId: unknown, productType: unknown): boolean =>
    p.symID === symbolId && p.productType === productType

  // Mock fill: nets into a same-symbol, same-product position, and an order
  // with no such position stays pending. (`placeOrder` only.)
  const fillIntoPosition = (p: Row): void => {
    const position = positions.find((x) => sameLine(x, p.symID, p.productType))
    if (!position) return
    const qty = num(p.qty)
    position.netQty = num(position.netQty) + (isBuy(p.orderAction) ? qty : -qty)
  }

  // A fully filled order, as `groupAdjustOrders` produces for each leg.
  const filledOrder = (leg: Row): Row => ({
    orderID: idOf(++orderCounter, 'ORD'),
    symbol: symbolOrStub(String(leg.id)),
    type: leg.ordType,
    orderAction: leg.action,
    productType: leg.productType,
    avgPrice: num(leg.price),
    price: num(leg.price),
    netQty: num(leg.quantity),
    fillQty: num(leg.quantity),
    orderStatus: 'completed',
    triggerPrice: 0,
    ordTime: formatOrdTime(0),
  })

  const upsertPosition = (leg: Row): void => {
    const qty = isBuy(leg.action) ? num(leg.quantity) : -num(leg.quantity)
    const price = num(leg.price)
    const existing = positions.find((x) => sameLine(x, leg.id, leg.productType))
    if (!existing) {
      positions.push({
        symID: leg.id,
        displayName: symbolOrStub(String(leg.id)).name,
        netQty: qty,
        avgPrice: price,
        netOrgAvgPrice: price,
        pnl: 0,
        realizedPnl: 0,
        realizedOrgPnl: 0,
        unrealizedPL: 0,
        mtm: 0,
        multiplier: 1,
        priceFactor: 1,
        productType: leg.productType,
        symbol: symbolOrStub(String(leg.id)),
      })
      return
    }
    existing.netQty = num(existing.netQty) + qty
    existing.avgPrice = price
    existing.netOrgAvgPrice = price
    if (existing.netQty === 0) positions.splice(positions.indexOf(existing), 1)
  }

  // Live P&L on every position, then the alert and OCO trigger checks.
  const onTick = (): void => {
    for (const position of positions) {
      const pnl = positionPnl(position)
      position.pnl = pnl
      position.unrealizedPL = pnl
      position.mtm = pnl
    }
    dispatch('positions', positions)

    const firedAlerts = alerts.filter(
      (a) =>
        a.enabled === true &&
        a.triggered !== true &&
        Math.abs(priceOf(String((a.symbolInfo as Row).id)) - num(a.triggerPrice)) <= 2,
    )
    for (const alert of firedAlerts) {
      alert.triggered = true
      feedback(`Alert ${String(alert.alertId)} triggered`)
    }
    if (firedAlerts.length > 0) dispatch('alerts', alerts)

    // Side-aware: a sell OCO protects a long (SL below, TP above); a buy OCO
    // protects a short (SL above, TP below).
    const firedOcos = ocoOrders.filter((oco) => {
      const price = priceOf(String(oco.symID))
      const sl = num((oco.stopLoss as Row).triggerPrice)
      const tp = num((oco.target as Row).triggerPrice)
      return isBuy(oco.side) ? price >= sl || price <= tp : price <= sl || price >= tp
    })
    if (firedOcos.length > 0) {
      ocoOrders = ocoOrders.filter((o) => !firedOcos.includes(o))
      for (const oco of firedOcos) feedback(`OCO ${String(oco.groupId)} triggered`)
      dispatch('ocoOrders', ocoOrders)
    }
  }

  const tickTimer = setInterval(() => {
    const ticks = nextTicks(subscribed)
    if (ticks.length > 0) dispatch('marketData', ticks)
    onTick()
  }, 1000)
  const snapshotTimer = setInterval(() => {
    dispatch('orders', orders)
    dispatch('ocoOrders', ocoOrders)
  }, 2000)

  const host: NeoChartsHostObject = {
    init: () => Promise.resolve(sessionJson()),
    loadData: (symbolId, _from, to, intervalSeconds, requiredBars) =>
      Promise.resolve(
        JSON.stringify(makeBars(requiredBars, intervalSeconds * 1000, to, symbolId)),
      ),
    // The passed set is the complete desired subscription: replace, don't add.
    subscribeMarketData: (symbolIds) => {
      subscribed = [...symbolIds]
    },
    searchSymbols: (query) => Promise.resolve(searchSymbols(query)),
    optionChain: (underlyingId) => Promise.resolve(optionChainJson(underlyingId)),
    futures: (underlyingId) => Promise.resolve(futuresJson(underlyingId)),
    underlyingOf: (symbolId) => Promise.resolve(underlyingOfJson(symbolId)),
    marginFor: (request) => Promise.resolve(marginForJson(request)),
    brokerageFor: (request) => Promise.resolve(brokerageForJson(request)),
    // Mock: every symbol is tradable. Anything but JSON 'true' blocks trading.
    isTradingEnabled: () => Promise.resolve('true'),

    placeOrder: (params) => {
      orderCounter++
      const p = parse(params)
      orders.push(placedOrder(idOf(orderCounter, 'ORD'), p))
      fillIntoPosition(p)
      dispatch('orders', orders)
      dispatch('positions', positions)
      feedback('Order placed')
    },
    modifyOrder: (params) => {
      const p = parse(params)
      const idx = orders.findIndex((o) => o.orderID === p.orderID)
      if (idx < 0) return
      orders[idx] = {
        ...orders[idx],
        price: p.price ?? 0,
        avgPrice: p.price ?? 0,
        netQty: p.qty ?? 0,
        type: p.orderType ?? 'limit',
        orderAction: p.orderAction ?? 'buy',
        productType: p.productType ?? orders[idx].productType,
        ...(p.triggerPrice == null ? {} : { triggerPrice: p.triggerPrice }),
      }
      dispatch('orders', orders)
    },
    cancelOrder: (orderId) => {
      const order = orders.find((o) => o.orderID === orderId)
      if (!order) return
      order.orderStatus = 'cancelled'
      dispatch('orders', orders)
      feedback('Order cancelled', 'negative')
    },
    // `{exit: [leg], add: [leg]}`: exits close a symbol's positions, adds
    // fill and upsert one. Both leave a completed order behind.
    groupAdjustOrders: (request) => {
      const { exit = [], add = [] } = JSON.parse(request) as { exit?: Row[]; add?: Row[] }
      for (const leg of exit) {
        positions = positions.filter((x) => x.symID !== leg.id)
        orders.push(filledOrder(leg))
      }
      for (const leg of add) {
        orders.push(filledOrder(leg))
        upsertPosition(leg)
      }
      dispatch('orders', orders)
      dispatch('positions', positions)
      feedback('Adjustment submitted')
    },

    placeOcoOrder: (params) => {
      ocoGroupCounter++
      const p = parse(params)
      const symbol = symbolOrStub(String(p.symID))
      ocoOrders.push({
        groupId: idOf(ocoGroupCounter, 'OCO'),
        symID: p.symID,
        name: symbol.name,
        exchange: symbol.exchange,
        side: p.side,
        productType: p.productType,
        stopLoss: {
          type: 'stopLoss',
          side: p.side,
          triggerPrice: p.stopPrice,
          qty: p.stopQty,
          price: p.stopPrice,
          fillQty: 0,
        },
        target: {
          type: 'limit',
          side: p.side,
          triggerPrice: p.targetTriggerPrice,
          qty: p.targetQty,
          price: p.targetPrice,
          fillQty: 0,
        },
      })
      dispatch('ocoOrders', ocoOrders)
      feedback('OCO order placed')
    },
    modifyOcoOrder: (params) => {
      const p = parse(params)
      const idx = ocoOrders.findIndex((o) => o.groupId === p.groupId)
      if (idx < 0) return
      const oco = ocoOrders[idx]
      ocoOrders[idx] = {
        ...oco,
        stopLoss: {
          ...(oco.stopLoss as Row),
          triggerPrice: p.stopPrice,
          price: p.stopPrice,
        },
        target: {
          ...(oco.target as Row),
          triggerPrice: p.targetTriggerPrice,
          price: p.targetPrice,
        },
      }
      dispatch('ocoOrders', ocoOrders)
    },
    cancelOcoOrder: (groupId) => {
      ocoOrders = ocoOrders.filter((o) => o.groupId !== groupId)
      dispatch('ocoOrders', ocoOrders)
      feedback('OCO order cancelled', 'negative')
    },

    createAlert: (params) => {
      const p = parse(params)
      alertCounter++
      alerts.push({
        alertId: idOf(alertCounter, 'ALT'),
        symbolInfo: symbolOrStub(String(p.symbolId)) as unknown as Row,
        triggerPrice: p.triggerPrice,
        enabled: true,
        triggered: false,
        createdAt: Date.now(),
      })
      dispatch('alerts', alerts)
      feedback('Alert created')
    },
    modifyAlert: (params) => {
      const p = parse(params)
      const idx = alerts.findIndex((a) => a.alertId === p.alertId)
      if (idx < 0) return
      alerts[idx] = { ...alerts[idx], triggerPrice: p.triggerPrice }
      dispatch('alerts', alerts)
    },
    deleteAlert: (alertId) => {
      if (!alerts.some((a) => a.alertId === alertId)) return
      alerts = alerts.filter((a) => a.alertId !== alertId)
      dispatch('alerts', alerts)
      feedback('Alert deleted')
    },

    oiAnalysis: (underlyingId) => Promise.resolve(oiAnalysisJson(underlyingId)),
    oiChange: (underlyingId) => Promise.resolve(oiChangeJson(underlyingId)),
    oi: (underlyingId) => Promise.resolve(oiJson(underlyingId)),

    pcrIntraday: (underlyingId) => Promise.resolve(pcrIntradayJson(underlyingId)),
    atmStraddleIntraday: (underlyingId) =>
      Promise.resolve(atmStraddleIntradayJson(underlyingId)),
    atmIvIntraday: (underlyingId) => Promise.resolve(atmIvIntradayJson(underlyingId)),

    fetchFunds: () =>
      Promise.resolve(JSON.stringify({ availableMargin: 347500.0, usedMargin: 152500.0 })),
    fetchTopOptions: (underlyingId) => Promise.resolve(topOptionsJson(underlyingId)),
    onClose: () => {
      location.href = location.pathname
    },
  }

  return {
    host,
    stop: () => {
      stopped = true
      clearInterval(tickTimer)
      clearInterval(snapshotTimer)
    },
  }
}
