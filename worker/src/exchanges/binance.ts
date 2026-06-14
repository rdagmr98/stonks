import type { ExchangeHolding } from '../index'

// Binance Spot API
// Auth: query param signature = HMAC-SHA256(secret, queryString)
// Docs: https://binance-docs.github.io/apidocs/spot/en/

const BASE = 'https://api.binance.com'

// Stablecoins and fiat to skip (zero investment value)
const SKIP = new Set(['USDT', 'USDC', 'BUSD', 'EUR', 'USD', 'LDUSDT', 'LDBTC'])

async function hmac256(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message))
  return Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('')
}

interface BinanceBalance {
  asset: string
  free: string
  locked: string
}

interface BinanceAccount {
  balances: BinanceBalance[]
}

export async function fetchBinance(apiKey: string, apiSecret: string): Promise<ExchangeHolding[]> {
  const timestamp = Date.now().toString()
  const query = `timestamp=${timestamp}`
  const signature = await hmac256(apiSecret, query)

  const res = await fetch(`${BASE}/api/v3/account?${query}&signature=${signature}`, {
    headers: { 'X-MBX-APIKEY': apiKey },
  })
  if (!res.ok) throw new Error(`Binance account: ${res.status}`)

  const { balances } = await res.json<BinanceAccount>()

  return balances
    .filter(b => {
      const total = parseFloat(b.free) + parseFloat(b.locked)
      return total > 0 && !SKIP.has(b.asset)
    })
    .map(b => ({
      symbol: b.asset,
      amount: parseFloat(b.free) + parseFloat(b.locked),
      exchange: 'binance',
    }))
}
