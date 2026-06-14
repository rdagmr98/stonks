import { Hono } from 'hono'
import { cors } from 'hono/cors'
import type { Context } from 'hono'
import { fetchCoinbase } from './exchanges/coinbase'
import { fetchBinance } from './exchanges/binance'
import { fetchKraken } from './exchanges/kraken'

export interface Env {
  GH_TOKEN: string
  AUTH_PASSWORD: string  // SHA-256 hex of the app password (e.g. stonks123)
  COINBASE_KEY?: string
  COINBASE_SECRET?: string
  BINANCE_KEY?: string
  BINANCE_SECRET?: string
  KRAKEN_KEY?: string
  KRAKEN_SECRET?: string
}

const app = new Hono<{ Bindings: Env }>()

app.use('*', cors({
  origin: (origin) => {
    if (!origin) return '*'
    if (origin.startsWith('http://localhost')) return origin
    if (origin === 'https://rdagmr98.github.io') return origin
    return null
  },
  allowMethods: ['GET', 'PUT', 'POST', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400,
}))

const authMiddleware = async (c: Context<{ Bindings: Env }>, next: () => Promise<void>) => {
  const header = c.req.header('Authorization')
  if (!header?.startsWith('Bearer ')) return c.json({ error: 'Unauthorized' }, 401)
  const token = header.slice(7)
  if (token !== c.env.AUTH_PASSWORD) return c.json({ error: 'Forbidden' }, 403)
  await next()
}

// Health check — no auth
app.get('/api/health', (c) => c.json({ ok: true, version: '1.0.0' }))

// ── GitHub proxy ──────────────────────────────────────────────────────────────
const GH_OWNER = 'rdagmr98'
const GH_REPO  = 'stonks-data'
const GH_BRANCH = 'main'

const ghHeaders = (token: string) => ({
  Authorization: `token ${token}`,
  Accept: 'application/vnd.github.v3+json',
  'Content-Type': 'application/json',
  'User-Agent': 'stonks-worker/1.0',
})

app.get('/api/data/:file', authMiddleware, async (c) => {
  const file = c.req.param('file')
  const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${file}?ref=${GH_BRANCH}`
  const res = await fetch(url, { headers: ghHeaders(c.env.GH_TOKEN) })
  const body = await res.json()
  return c.json(body, res.status as 200)
})

app.put('/api/data/:file', authMiddleware, async (c) => {
  const file = c.req.param('file')
  const payload = await c.req.json<{ content: string; sha?: string; message?: string }>()
  const url = `https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/contents/${file}`
  const res = await fetch(url, {
    method: 'PUT',
    headers: ghHeaders(c.env.GH_TOKEN),
    body: JSON.stringify({
      message: payload.message ?? `update ${file}`,
      content: payload.content,
      branch: GH_BRANCH,
      ...(payload.sha ? { sha: payload.sha } : {}),
    }),
  })
  const body = await res.json()
  return c.json(body, res.status as 200)
})

// ── Exchange sync ─────────────────────────────────────────────────────────────
export interface ExchangeHolding {
  symbol: string   // e.g. "BTC", "ETH"
  amount: number   // quantity held
  exchange: string // "coinbase" | "binance" | "kraken"
}

app.post('/api/sync', authMiddleware, async (c) => {
  const results: Record<string, ExchangeHolding[] | { error: string }> = {}

  if (c.env.COINBASE_KEY && c.env.COINBASE_SECRET) {
    try { results.coinbase = await fetchCoinbase(c.env.COINBASE_KEY, c.env.COINBASE_SECRET) }
    catch (e) { results.coinbase = { error: String(e) } }
  }
  if (c.env.BINANCE_KEY && c.env.BINANCE_SECRET) {
    try { results.binance = await fetchBinance(c.env.BINANCE_KEY, c.env.BINANCE_SECRET) }
    catch (e) { results.binance = { error: String(e) } }
  }
  if (c.env.KRAKEN_KEY && c.env.KRAKEN_SECRET) {
    try { results.kraken = await fetchKraken(c.env.KRAKEN_KEY, c.env.KRAKEN_SECRET) }
    catch (e) { results.kraken = { error: String(e) } }
  }

  return c.json(results)
})

app.post('/api/sync/:exchange', authMiddleware, async (c) => {
  const exchange = c.req.param('exchange')
  try {
    let result: ExchangeHolding[]
    switch (exchange) {
      case 'coinbase':
        if (!c.env.COINBASE_KEY || !c.env.COINBASE_SECRET)
          return c.json({ error: 'Coinbase non configurato' }, 400)
        result = await fetchCoinbase(c.env.COINBASE_KEY, c.env.COINBASE_SECRET)
        break
      case 'binance':
        if (!c.env.BINANCE_KEY || !c.env.BINANCE_SECRET)
          return c.json({ error: 'Binance non configurato' }, 400)
        result = await fetchBinance(c.env.BINANCE_KEY, c.env.BINANCE_SECRET)
        break
      case 'kraken':
        if (!c.env.KRAKEN_KEY || !c.env.KRAKEN_SECRET)
          return c.json({ error: 'Kraken non configurato' }, 400)
        result = await fetchKraken(c.env.KRAKEN_KEY, c.env.KRAKEN_SECRET)
        break
      default:
        return c.json({ error: `Exchange '${exchange}' non supportato` }, 400)
    }
    return c.json(result)
  } catch (e) {
    return c.json({ error: String(e) }, 500)
  }
})

export default app
