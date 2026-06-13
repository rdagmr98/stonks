# Stonks — Flutter Portfolio Tracker

Repo app: `rdagmr98/stonks` | Repo dati: `rdagmr98/stonks-data`
Vault Obsidian: `C:\Users\Gianmarco\ObsidianVault\Stonks\Stonks.md`

## Release workflow
```
flutter build apk --release
git add lib/...
git commit -m "..."
git push origin main   ← autorizzato, sempre senza chiedere
```

## Architettura
- Flutter app dark-theme (GitHub-inspired: kBg/kSurface/kCard/kGreen/kRed)
- Clone di getquin — portfolio tracker azionario/ETF/crypto
- `GhDbService`: singleton, GitHub API REST, SHA versioning, retry 3x su 409, cache in-memoria
- `MarketService`: Yahoo Finance API v8, cache 5 min, cambio valuta via `{FROM}{TO}=X`
- DB: `rdagmr98/stonks-data` → `users.json`, `portfolio.json`, `transactions.json`, `watchlist.json`

## Struttura lib/
```
lib/
├── main.dart
├── router.dart
├── theme/app_theme.dart
├── models/
│   ├── holding.dart          — posizione (symbol, shares, avgCost)
│   ├── transaction.dart      — transazione (buy/sell/dividend)
│   ├── watchlist_item.dart   — item watchlist + target price
│   ├── app_user.dart         — utente con ruolo
│   └── quote.dart            — quotazione live (price, change, changePercent)
├── services/
│   ├── gh_db_service.dart    — GitHub JSON backend
│   ├── portfolio_service.dart — CRUD holdings/tx/watchlist + recompute holding
│   ├── market_service.dart   — prezzi live Yahoo Finance
│   ├── auth_service.dart     — login/logout/auto-login (SharedPreferences)
│   └── crypto_service.dart   — AES-CBC encrypt/decrypt
├── providers/
│   └── providers.dart        — Riverpod providers + PortfolioSummary
├── screens/
│   ├── auth/login_screen.dart
│   ├── dashboard/dashboard_screen.dart  — valore totale, P&L, allocazione pie
│   ├── portfolio/portfolio_screen.dart  — lista holdings ordinata per valore
│   ├── transactions/
│   │   ├── transactions_screen.dart     — lista tx con swipe-to-delete
│   │   └── add_transaction_screen.dart — form buy/sell/dividend
│   ├── watchlist/watchlist_screen.dart  — watchlist con target price
│   └── shell_screen.dart               — NavigationBar 4 tab
└── widgets/
    ├── holding_tile.dart      — card holding con P&L e variazione giornaliera
    └── allocation_chart.dart  — PieChart allocazione per simbolo
```

## Schermate
| Tab | Screen | Funzione |
|-----|--------|----------|
| Home | dashboard | Valore totale, P&L oggi/totale, pie allocazione, lista holdings |
| Portfolio | portfolio | Lista holdings ordinata per valore, FAB → add transaction |
| Transazioni | transactions | Storia completa, swipe-to-delete, FAB → add |
| Watchlist | watchlist | Lista con prezzo live + target, FAB → add |

## Utente default
- username: `gianmarco` | password: `stonks123`
- SHA-256: `43c7f47090a7225a6da84c491e44971211e4ee47aee683b9be242f6d48d08b8a`

## Variabili d'ambiente
- `GH_TOKEN` — Personal Access Token GitHub (scope: repo)
- `STONKS_AES_KEY` — chiave AES-256 base64 (opzionale, default built-in)

## STATO SESSIONE — aggiornato 2026-06-13
- Progetto creato da zero. App funzionale con 4 tab.
- TODO:
  - [ ] Aggiungere schermata dettaglio holding (grafico storico prezzi)
  - [ ] Dividend tracker dedicato
  - [ ] Import CSV transazioni
  - [ ] GitHub Actions per build APK automatica
  - [ ] Impostare GH_TOKEN nel build
