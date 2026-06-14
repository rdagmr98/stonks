import type { ExchangeHolding } from '../index'

// Coinbase Advanced Trade API v3
// Auth: HMAC-SHA256(secret, timestamp + method + path + body)
// Docs: https://docs.cdp.coinbase.com/advanced-trade/reference/

const BASE = 'https://api.coinbase.com'

async function sign(secret: string, message: string): Promise<string> {
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

async function cbFetch(apiKey: string, apiSecret: string, path: string): Promise<Response> {
  const timestamp = Math.floor(Date.now() / 1000).toString()
  const method = 'GET'
  const signature = await sign(apiSecret, timestamp + method + path + '')
  return fetch(`${BASE}${path}`, {
    headers: {
      'CB-ACCESS-KEY': apiKey,
      'CB-ACCESS-SIGN': signature,
      'CB-ACCESS-TIMESTAMP': timestamp,
      'Content-Type': 'application/json',
    },
  })
}

interface CbAccount {
  currency: { code: string }
  balance: { amount: string }
  type: string
}

export async function fetchCoinbase(apiKey: string, apiSecret: string): Promise<ExchangeHolding[]> {
  const res = await cbFetch(apiKey, apiSecret, '/v2/accounts?limit=100')
  if (!res.ok) throw new Error(`Coinbase accounts: ${res.status}`)

  const { data } = await res.json<{ data: CbAccount[] }>()

  return data
    .filter(a => parseFloat(a.balance.amount) > 0)
    .map(a => ({
      symbol: a.currency.code,
      amount: parseFloat(a.balance.amount),
      exchange: 'coinbase',
    }))
}
