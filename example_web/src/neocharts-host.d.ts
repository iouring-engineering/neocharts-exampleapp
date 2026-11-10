// Vendored verbatim from the SDK's web/neocharts-host.d.ts; refresh it on each SDK release.
// Type declarations for the NeoCharts web SDK's host contract.
//
// The bundle ships `neocharts.js`. Load only that script, then call
// `neoCharts.mount(element, host, options)`. Payload shapes (orders,
// positions, candles, ...): https://docs-neocharts.iouring.com/docs/quick-start/web
//
// - Load `neocharts.js` as a classic `<script src>`, not a module or a
//   bundler import, or it throws at load time.
// - If you inject the script with JS, wait for its `onload` before calling
//   `neoCharts.mount`. Nothing is queued before the script has run.
// - A `?v=` query on `neocharts.js` is not carried to the engine files it
//   loads.
// - A boot failure before the engine starts (a file that did not load)
//   rejects `mount`, and the next `mount` retries. A failure after the
//   engine started stays until the page reloads.
// - Loading `neocharts.js` a second time is a no-op.
//
// Every host method takes positional arguments and, unless noted, takes and
// returns JSON strings.

/** A symbol as the host sends it; only `id` is required. */
export interface NeoChartsSymbol {
  id: string
  name?: string
  exchange?: string
  segment?: 'EQ' | 'FUT' | 'OPT' | 'CD' | 'COM' | ''
  lotSize?: number
  precision?: number
  tickSize?: number
  expiry?: string
  strike?: string
  optType?: string
  undID?: string
  weekly?: string
  description?: string
  trdUnit?: string
}

/** One exchange's trading calendar, in its own time zone. */
export interface NeoChartsMarketTiming {
  /** An IANA zone, e.g. `Asia/Kolkata`. */
  timezone: string
  /** Index 0 = Monday ... 6 = Sunday; each day's `"HHMM-HHMM"` ranges. */
  sessions: string[][]
  /** Closed dates, `"YYYYMMDD"`. */
  holidays: string[]
  /** `"YYYYMMDD"` to that day's ranges, replacing its weekday's. */
  special: { [date: string]: string[] }
}

/**
 * The JSON string `init()` resolves, the same as native.
 * `capabilities`, `homeKey` and `widgetOverrides` are native-only and ignored
 * on web.
 */
export interface NeoChartsSession {
  /** `exchange` is required: it picks the market timing. */
  initialSymbol: NeoChartsSymbol & { exchange: string }
  /** Must not be blank. */
  storageKey: string
  /**
   * Keyed by exchange, matched case-insensitively; MUST include
   * `initialSymbol.exchange`.
   */
  marketTimings: { [exchange: string]: NeoChartsMarketTiming }
  isMarketOrderSupported?: boolean
  /**
   * Keyed by segment (`EQ`, `FUT`, `OPT`, `CD`, `COM`). `values` must be
   * non-empty and contain `default`; a segment that breaks this, or an
   * unknown one, is skipped and logged.
   */
  productTypes?: { [segment: string]: { values: string[]; default: string } }
  /** The spot indices; never tradable. Absent or null is none. */
  indexSymbols?: NeoChartsSymbol[]
}

/** What a fire-and-forget method may return; a rejection is only logged. */
export type NeoChartsFireAndForget = void | Promise<unknown>

/** Required methods. */
export interface NeoChartsHost {
  /** Resolves a JSON `NeoChartsSession`. */
  init(): Promise<string>
  loadData(
    symbolId: string,
    from: number,
    to: number,
    intervalSeconds: number,
    requiredBars: number,
  ): Promise<string | null>
  /** Each call replaces the subscribed set. */
  subscribeMarketData(symbolIds: string[]): void
  searchSymbols(query: string): Promise<string | null>
  /** Contracts only, no side effects. */
  optionChain(underlyingId: string): Promise<string | null>
  futures(underlyingId: string): Promise<string | null>
  /** Total: an underlying returns itself. */
  underlyingOf(symbolId: string): Promise<string>
  /**
   * The order pad's margin preview. `request` is JSON
   * `{action, lots, ltp, symbolId, productType?}`; resolve a JSON number, or
   * null or blank to show none for this order.
   */
  marginFor(request: string): Promise<string | null>
  /**
   * The order pad's brokerage preview. `request` is JSON
   * `{action, quantity, price, symbolId, productType?}`; resolve as
   * `marginFor`.
   */
  brokerageFor(request: string): Promise<string | null>
  /** JSON `'true'` allows trading `symbolId`; anything else blocks it. */
  isTradingEnabled(symbolId: string): Promise<string>
  placeOrder(params: string): NeoChartsFireAndForget
  modifyOrder(params: string): NeoChartsFireAndForget
  cancelOrder(orderId: string): NeoChartsFireAndForget
  groupAdjustOrders(request: string): NeoChartsFireAndForget
}

// Optional groups: implement all of a group's methods or none of them; a
// partial group is disabled with a console warning. Groups are read from the
// host object when `mount` is called, before `init()` runs, so methods added
// during `init()` are ignored.

export interface NeoChartsOco {
  placeOcoOrder(params: string): NeoChartsFireAndForget
  modifyOcoOrder(params: string): NeoChartsFireAndForget
  cancelOcoOrder(groupId: string): NeoChartsFireAndForget
}

export interface NeoChartsAlerts {
  createAlert(params: string): NeoChartsFireAndForget
  modifyAlert(params: string): NeoChartsFireAndForget
  deleteAlert(alertId: string): NeoChartsFireAndForget
}

export interface NeoChartsOiAnalytics {
  oiAnalysis(
    underlyingSymbolId: string,
    expiry: string,
    timeFrom: number,
    timeTo: number,
  ): Promise<string | null>
  oiChange(
    underlyingSymbolId: string,
    expiries: string[],
    timeFrom: number,
    timeTo: number,
  ): Promise<string | null>
  oi(underlyingSymbolId: string, expiries: string[]): Promise<string | null>
}

export interface NeoChartsIntradayAnalytics {
  pcrIntraday(underlyingId: string): Promise<string | null>
  atmStraddleIntraday(underlyingId: string): Promise<string | null>
  atmIvIntraday(underlyingId: string): Promise<string | null>
}

export interface NeoChartsFunds {
  fetchFunds(): Promise<string | null>
}

export interface NeoChartsTopOptions {
  fetchTopOptions(underlyingId: string): Promise<string | null>
}

export interface NeoChartsClose {
  onClose(): void
}

/** The host object: the core plus any optional groups. */
export type NeoChartsHostObject = NeoChartsHost &
  Partial<NeoChartsOco> &
  Partial<NeoChartsAlerts> &
  Partial<NeoChartsOiAnalytics> &
  Partial<NeoChartsIntradayAnalytics> &
  Partial<NeoChartsFunds> &
  Partial<NeoChartsTopOptions> &
  Partial<NeoChartsClose>

/**
 * Pushes: `CustomEvent<string>` (a JSON payload) dispatched ON THE MOUNT
 * ELEMENT. `ocoOrders` needs the OCO group, `alerts` the Alerts group; a
 * blank alerts `detail` is no event.
 */
export interface NeoChartsEventMap {
  'neocharts:marketData': CustomEvent<string>
  'neocharts:orders': CustomEvent<string>
  'neocharts:positions': CustomEvent<string>
  'neocharts:actionFeedback': CustomEvent<string>
  'neocharts:ocoOrders': CustomEvent<string>
  'neocharts:alerts': CustomEvent<string>
}

/** A `#RRGGBB` color per token; an omitted token keeps the built-in one. */
export interface NeoChartsColors {
  primary?: string
  onPrimary?: string
  onSecondary?: string
  surface?: string
  onSurface?: string
  surfaceContainer?: string
  surfaceContainerHigh?: string
  onSurfaceVariant?: string
  inverseSurface?: string
  onInverseSurface?: string
  outline?: string
  bullish?: string
  bearish?: string
  liveMarker?: string
}

export interface NeoChartsTheme {
  /** `null` or omitted follows the system. */
  brightness?: 'light' | 'dark' | null
  colors?: { light?: NeoChartsColors; dark?: NeoChartsColors }
}

/** A font family and its files, one per weight (400, 500, 600) or one variable font. */
export interface NeoChartsFont {
  family: string
  /** Paths resolve against the page; another origin needs CORS. */
  files: string[]
}

export interface NeoChartsMountOptions {
  /** A theme object or its JSON string. */
  theme?: NeoChartsTheme | string
  /** Read once per mount; the chart waits up to 3 s for it, then uses its built-in fonts. */
  font?: NeoChartsFont | string
  /** Defaults to `/neocharts-key.json` on the page origin. */
  licenseKeyUrl?: string
}

export interface NeoChartsHandle {
  unmount(): void
  /** A theme object or its JSON string. */
  setTheme(theme: NeoChartsTheme | string): void
}

export interface NeoChartsGlobal {
  /**
   * Mounts a chart in `element`; rejects with `Error('NeoCharts: ...')`.
   *
   * One chart at a time: a new `mount` replaces the old one, and a mount
   * replaced before it is up resolves with a handle that does nothing. An
   * unusable `init`, or none within 10 s, shows "Chart couldn't start" and
   * rejects; that chart stays until the next `mount` or `neoCharts.unmount()`.
   * After unmount, pushes are ignored and no fire-and-forget calls (orders,
   * alerts, `subscribeMarketData`) are sent, so stop your own streams then. A
   * request already in flight may still reach the host; its answer is
   * dropped.
   */
  mount(
    element: HTMLElement,
    host: NeoChartsHostObject,
    options?: NeoChartsMountOptions,
  ): Promise<NeoChartsHandle>
  /** Removes the current chart, if any. */
  unmount(): void
}

declare global {
  interface Window {
    neoCharts: NeoChartsGlobal
  }
}
