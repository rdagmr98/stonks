import 'package:uuid/uuid.dart';
import '../models/holding.dart';
import '../models/transaction.dart';
import '../models/watchlist_item.dart';
import 'gh_db_service.dart';

const _uuid = Uuid();

class PortfolioService {
  static final PortfolioService _instance = PortfolioService._();
  factory PortfolioService() => _instance;
  PortfolioService._();

  final _db = GhDbService();

  // Holdings
  Future<List<Holding>> getHoldings() async {
    final (list, _) = await _db.readList('portfolio.json');
    return list.map((e) => Holding.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveHoldings(List<Holding> holdings) async {
    final (_, sha) = await _db.readList('portfolio.json');
    await _db.writeList('portfolio.json', holdings.map((h) => h.toJson()).toList(), sha: sha);
  }

  Future<void> upsertHolding(Holding h) async {
    final holdings = await getHoldings();
    final idx = holdings.indexWhere((e) => e.id == h.id);
    if (idx >= 0) {
      holdings[idx] = h;
    } else {
      holdings.add(h);
    }
    await saveHoldings(holdings);
  }

  Future<void> removeHolding(String id) async {
    final holdings = await getHoldings();
    holdings.removeWhere((h) => h.id == id);
    await saveHoldings(holdings);
  }

  // Transactions
  Future<List<StTransaction>> getTransactions() async {
    final (list, _) = await _db.readList('transactions.json');
    return list.map((e) => StTransaction.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addTransaction(StTransaction tx) async {
    final (list, sha) = await _db.readList('transactions.json');
    list.add(tx.toJson());
    await _db.writeList('transactions.json', list, sha: sha);
    // Recompute holding
    await _recomputeHolding(tx.symbol, tx.name, tx.currency);
  }

  Future<void> deleteTransaction(String txId, String symbol, String name, String currency) async {
    final (list, sha) = await _db.readList('transactions.json');
    list.removeWhere((e) => (e as Map)['id'] == txId);
    await _db.writeList('transactions.json', list, sha: sha);
    await _recomputeHolding(symbol, name, currency);
  }

  Future<void> _recomputeHolding(String symbol, String name, String currency) async {
    final allTx = await getTransactions();
    final txs = allTx.where((t) => t.symbol == symbol && (t.type == 'buy' || t.type == 'sell')).toList();

    double totalShares = 0;
    double totalCost = 0;

    for (final t in txs) {
      if (t.type == 'buy') {
        totalCost += t.shares * t.price + t.fees;
        totalShares += t.shares;
      } else {
        final shareRatio = t.shares / totalShares;
        totalCost -= totalCost * shareRatio;
        totalShares -= t.shares;
      }
    }

    final holdings = await getHoldings();
    if (totalShares <= 0.00001) {
      holdings.removeWhere((h) => h.symbol == symbol);
    } else {
      final avgCost = totalCost / totalShares;
      final existing = holdings.indexWhere((h) => h.symbol == symbol);
      final holding = Holding(
        id: existing >= 0 ? holdings[existing].id : _uuid.v4(),
        symbol: symbol,
        name: name,
        type: _inferType(symbol),
        currency: currency,
        shares: totalShares,
        avgCost: avgCost,
      );
      if (existing >= 0) {
        holdings[existing] = holding;
      } else {
        holdings.add(holding);
      }
    }
    await saveHoldings(holdings);
  }

  String _inferType(String symbol) {
    final s = symbol.toUpperCase();
    if (s.endsWith('-USD') || s.endsWith('-EUR') || ['BTC', 'ETH', 'SOL', 'ADA', 'XRP'].contains(s)) {
      return 'crypto';
    }
    return 'stock';
  }

  // Watchlist
  Future<List<WatchlistItem>> getWatchlist() async {
    final (list, _) = await _db.readList('watchlist.json');
    return list.map((e) => WatchlistItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addToWatchlist(WatchlistItem item) async {
    final (list, sha) = await _db.readList('watchlist.json');
    list.add(item.toJson());
    await _db.writeList('watchlist.json', list, sha: sha);
  }

  Future<void> removeFromWatchlist(String id) async {
    final (list, sha) = await _db.readList('watchlist.json');
    list.removeWhere((e) => (e as Map)['id'] == id);
    await _db.writeList('watchlist.json', list, sha: sha);
  }

  static String newId() => _uuid.v4();
}
