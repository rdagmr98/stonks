import type { ExchangeHolding } from '../index'

// Kraken Private API
// Auth: API-Sign = HMAC-SHA512(sha256(nonce+body), base64decode(secret))
// Docs: https://docs.kraken.com/rest/

const BASE = 'https://api.kraken.com'

// Kraken prefixes assets with X (crypto) or Z (fiat)
const FIAT = new Set(['ZUSD', 'ZEUR', 'ZGBP', 'ZJPY', 'ZCAD', 'ZAUD'])

async function buildSign(path: string, nonce: string, body: string, apiSecret: string): Promise<string> {
  const secretBytes = Uint8Array.from(atob(apiSecret), c => c.charCodeAt(0))

  const shaInput = new TextEncoder().encode(nonce + body)
  const shaBuffer = await crypto.subtle.digest('SHA-256', shaInput)

  const pathBytes = new TextEncoder().encode(path)
  const message = new Uint8Array(pathBytes.length + shaBuffer.byteLength)
  message.set(pathBytes)
  message.set(new Uint8Array(shaBuffer), pathBytes.length)

  const hmacKey = await crypto.subtle.importKey(
    'raw', secretBytes,
    { name: 'HMAC', hash: 'SHA-512' },
    false, ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', hmacKey, message)
  return btoa(String.fromCharCode(...new Uint8Array(sig)))
}

function normalizeAsset(asset: string): string {
  // Strip leading X or Z from Kraken asset codes, then map known names
  const map: Record<string, string> = {
    XXBT: 'BTC', XETH: 'ETH', XXRP: 'XRP', XXLM: 'XLM',
    XLTC: 'LTC', XADA: 'ADA', XDOT: 'DOT', XSOL: 'SOL',
  }
  return map[asset] ?? (asset.startsWith('X') || asset.startsWith('Z') ? asset.slice(1) : asset)
}

export async function fetchKraken(apiKey: string, apiSecret: string): Promise<ExchangeHolding[]> {
  const path = '/0/private/Balance'
  const nonce = Date.now().toString()
  const body = `nonce=${nonce}`
  const sign = await buildSign(path, nonce, body, apiSecret)

  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: {
      'API-Key': apiKey,
      'API-Sign': sign,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  })
  if (!res.ok) throw new Error(`Kraken balance: ${res.status}`)

  const data = await res.json<{ error: string[]; result: Record<string, string> }>()
  if (data.error?.length) throw new Error(`Kraken: ${data.error.join(', ')}`)

  return Object.entries(data.result)
    .filter(([asset, amount]) => !FIAT.has(asset) && parseFloat(amount) > 0)
    .map(([asset, amount]) => ({
      symbol: normalizeAsset(asset),
      amount: parseFloat(amount),
      exchange: 'kraken',
    }))
}
