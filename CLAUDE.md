# Stonks — Flutter Portfolio Tracker

Repo app: `rdagmr98/stonks`
Vault Obsidian: `C:\Users\Gianmarco\ObsidianVault\Stonks\Stonks.md`

## Release workflow
```
flutter build web --release --base-href "/stonks/" --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
git add lib/... && git commit -m "..." && git push origin main
```

## Architettura
- Flutter app dark-theme (GitHub-inspired: kBg/kSurface/kCard/kGreen/kRed)
- Clone di getquin — portfolio tracker azionario/ETF/crypto multi-utente
- **Backend: Supabase** (PostgreSQL + RLS + auth integrata)
  - Tabelle: `profiles`, `holdings`, `transactions`, `watchlist`, `wallet_connections`
  - RLS: ogni utente vede solo i propri dati (`auth.uid() = user_id`)
  - Trigger: auto-crea `profiles` row su registrazione
- `MarketService`: Yahoo Finance API v8, cache 5 min, cambio valuta via `{FROM}{TO}=X`
- `WalletService`: HMAC client-side Binance/Coinbase/Kraken; Blockstream/Etherscan/Solana RPC per indirizzi

## Struttura lib/
```
lib/
├── main.dart                 — Supabase.initialize + tryAutoLogin
├── router.dart               — go_router: /login /register /dashboard /wallets ecc
├── theme/app_theme.dart
├── models/
│   ├── holding.dart
│   ├── transaction.dart
│   ├── watchlist_item.dart
│   ├── app_user.dart         — id/email/username/currency (da profiles Supabase)
│   ├── wallet_connection.dart — exchange API o indirizzo crypto
│   └── quote.dart
├── services/
│   ├── auth_service.dart     — Supabase auth: login/register/logout/autoLogin
│   ├── portfolio_service.dart — CRUD Supabase: holdings/transactions/watchlist
│   ├── wallet_service.dart   — CRUD wallet_connections + fetch bilanci
│   └── market_service.dart   — prezzi live Yahoo Finance
├── providers/providers.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart    — email + password + link Registrati
│   │   └── register_screen.dart — email + username + password
│   ├── dashboard/dashboard_screen.dart
│   ├── portfolio/portfolio_screen.dart + holding_detail_screen.dart
│   ├── transactions/transactions_screen.dart + add_transaction_screen.dart + import_csv_screen.dart
│   ├── dividends/dividends_screen.dart
│   ├── watchlist/watchlist_screen.dart
│   ├── wallets/wallet_connections_screen.dart  — exchange API + indirizzi crypto
│   ├── settings/settings_screen.dart           — info account + logout
│   └── shell_screen.dart
└── widgets/holding_tile.dart + allocation_chart.dart
```

## Variabili d'ambiente (Supabase)
- `SUPABASE_URL` — URL progetto Supabase (pubblico, sicuro in bundle)
- `SUPABASE_ANON_KEY` — anon key Supabase (pubblico, sicuro via RLS)

## Setup Supabase (da fare una volta)
1. Crea progetto su supabase.com
2. Esegui `supabase/schema.sql` nell'SQL Editor del progetto
3. Copia Project URL + anon key
4. Aggiorna deploy.yml con `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

## STATO SESSIONE — aggiornato 2026-06-14
- Migrazione Supabase completa: auth multi-utente, tutte le tabelle con RLS.
- `gh_db_service.dart` eliminato, `stonks-data` repo non più usata.
- `worker/` presente ma non deployato (non più necessario con Supabase).
- Login con email (non username), registrazione pubblica via `/register`.
- `WalletConnectionsScreen`: collega exchange API + indirizzi BTC/ETH/SOL, sync bilanci.
- TODO:
  - [ ] Utente crea progetto Supabase e manda URL + anon key → aggiornare deploy.yml
  - [ ] (Opzionale) Etherscan API key per bilanci ETH
  - [ ] Ricerca simbolo/lookup nel form add-transaction
  - [ ] Performance chart portafoglio storico (value nel tempo)
