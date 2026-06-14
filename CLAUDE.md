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
│   ├── portfolio/
│   │   ├── portfolio_screen.dart        — lista holdings ordinata per valore
│   │   └── holding_detail_screen.dart  — dettaglio: grafico storico, posizione, transazioni
│   ├── transactions/
│   │   ├── transactions_screen.dart     — lista tx con swipe-to-delete
│   │   ├── add_transaction_screen.dart — form buy/sell/dividend
│   │   └── import_csv_screen.dart      — import CSV bulk con anteprima
│   ├── dividends/dividends_screen.dart — tracker dividendi: totale, bar chart mensile, per simbolo
│   ├── watchlist/watchlist_screen.dart  — watchlist con target price
│   └── shell_screen.dart               — NavigationBar 5 tab
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

## STATO SESSIONE — aggiornato 2026-06-14
- App funzionale con 5 tab: Home, Portfolio, Transazioni, Dividendi, Watchlist.
- `HoldingDetailScreen`: grafico LineChart storico, selettore range, linea pm tratteggiata, posizione card, lista tx.
- `DividendsScreen` (tab 4): totale all-time, bar chart mensile fl_chart, breakdown per simbolo con progress bar, lista transazioni tipo dividend.
- `ImportCsvScreen` (`/import-csv`): parsing CSV con anteprima, supporto date multiple, normalizzazione tipo (acquisto/buy/etc), import bulk sequenziale.
- `.github/workflows/build.yml`: CI che builda APK split-per-abi su ogni push main, artefatti 30gg.
- TODO:
  - [ ] Ricerca simbolo/lookup nel form add-transaction
  - [ ] Performance chart portafoglio storico (value nel tempo)
