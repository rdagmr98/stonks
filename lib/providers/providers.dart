import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/holding.dart';
import '../models/transaction.dart';
import '../models/watchlist_item.dart';
import '../models/quote.dart';
import '../services/portfolio_service.dart';
import '../services/market_service.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final holdingsProvider = FutureProvider<List<Holding>>((ref) async {
  return PortfolioService().getHoldings();
});

final transactionsProvider = FutureProvider<List<StTransaction>>((ref) async {
  return PortfolioService().getTransactions();
});

final watchlistProvider = FutureProvider<List<WatchlistItem>>((ref) async {
  return PortfolioService().getWatchlist();
});

final quotesProvider = FutureProvider.family<Quote?, String>((ref, symbol) async {
  return MarketService().fetchQuote(symbol);
});

final allQuotesProvider = FutureProvider<Map<String, Quote?>>((ref) async {
  final holdings = await ref.watch(holdingsProvider.future);
  final watchlist = await ref.watch(watchlistProvider.future);
  final symbols = {
    ...holdings.map((h) => h.symbol),
    ...watchlist.map((w) => w.symbol),
  }.toList();
  if (symbols.isEmpty) return {};
  return MarketService().fetchQuotes(symbols);
});

// Exchange rates: all currencies → EUR
final exchangeRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  final holdings = await ref.watch(holdingsProvider.future);
  final currencies = holdings.map((h) => h.currency).toSet().toList();
  return MarketService().getExchangeRates(currencies, 'EUR');
});

// Price history for a symbol
final priceHistoryProvider = FutureProvider.family<List<PricePoint>, (String, String)>(
  (ref, args) async {
    final (symbol, range) = args;
    return MarketService().fetchHistory(symbol, range);
  },
);

// Portfolio summary with currency conversion to EUR
final portfolioSummaryProvider = FutureProvider<PortfolioSummary>((ref) async {
  final holdings = await ref.watch(holdingsProvider.future);
  final quotes = await ref.watch(allQuotesProvider.future);
  final fxRates = await ref.watch(exchangeRatesProvider.future);

  double totalValue = 0;
  double totalCost = 0;
  double dailyChange = 0;

  for (final h in holdings) {
    final q = quotes[h.symbol];
    final quoteCurrency = q?.currency ?? h.currency;
    final fxToEur = fxRates[quoteCurrency] ?? 1.0;
    final costFxToEur = fxRates[h.currency] ?? 1.0;

    final priceEur = (q?.price ?? h.avgCost) * fxToEur;
    final value = h.shares * priceEur;
    totalValue += value;
    totalCost += h.totalCost * costFxToEur;
    dailyChange += h.shares * (q?.change ?? 0) * fxToEur;
  }

  return PortfolioSummary(
    totalValue: totalValue,
    totalCost: totalCost,
    totalPnl: totalValue - totalCost,
    totalPnlPct: totalCost > 0 ? (totalValue - totalCost) / totalCost * 100 : 0,
    dailyChange: dailyChange,
    dailyChangePct: totalValue > 0 ? dailyChange / (totalValue - dailyChange) * 100 : 0,
    holdingCount: holdings.length,
  );
});

class PortfolioSummary {
  final double totalValue;
  final double totalCost;
  final double totalPnl;
  final double totalPnlPct;
  final double dailyChange;
  final double dailyChangePct;
  final int holdingCount;

  const PortfolioSummary({
    required this.totalValue,
    required this.totalCost,
    required this.totalPnl,
    required this.totalPnlPct,
    required this.dailyChange,
    required this.dailyChangePct,
    required this.holdingCount,
  });
}
