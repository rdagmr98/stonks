import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/holding.dart';
import '../models/transaction.dart';
import '../models/watchlist_item.dart';

const _uuid = Uuid();

class PortfolioService {
  static final PortfolioService _instance = PortfolioService._();
  factory PortfolioService() => _instance;
  PortfolioService._();

  final _sb = Supabase.instance.client;
  String get _uid => _sb.auth.currentUser!.id;

  // ── Holdings ─────────────────────────────────────────────────────────────

  Future<List<Holding>> getHoldings() async {
    final rows = await _sb.from('holdings').select().eq('user_id', _uid);
    return rows.map((r) => Holding.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> _upsertHolding(Holding h) async {
    await _sb.from('holdings').upsert(
      {...h.toJson(), 'user_id': _uid},
      onConflict: 'user_id,symbol',
    );
  }

  Future<void> _deleteHolding(String symbol) async {
    await _sb.from('holdings').delete().eq('user_id', _uid).eq('symbol', symbol);
  }

  // ── Transactions ─────────────────────────────────────────────────────────

  Future<List<StTransaction>> getTransactions() async {
    final rows = await _sb.from('transactions').select().eq('user_id', _uid).order('date', ascending: false);
    return rows.map((r) => StTransaction.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> addTransaction(StTransaction tx) async {
    await _sb.from('transactions').insert({...tx.toJson(), 'user_id': _uid});
    await _recomputeHolding(tx.symbol, tx.name, tx.currency);
  }

  Future<void> deleteTransaction(String txId, String symbol, String name, String currency) async {
    await _sb.from('transactions').delete().eq('id', txId).eq('user_id', _uid);
    await _recomputeHolding(symbol, name, currency);
  }

  Future<void> _recomputeHolding(String symbol, String name, String currency) async {
    final rows = await _sb
        .from('transactions')
        .select()
        .eq('user_id', _uid)
        .eq('symbol', symbol);
    final txs = rows
        .map((r) => StTransaction.fromJson(r as Map<String, dynamic>))
        .where((t) => t.type == 'buy' || t.type == 'sell')
        .toList();

    double totalShares = 0, totalCost = 0;
    for (final t in txs) {
      if (t.type == 'buy') {
        totalCost += t.shares * t.price + t.fees;
        totalShares += t.shares;
      } else {
        final ratio = t.shares / totalShares;
        totalCost -= totalCost * ratio;
        totalShares -= t.shares;
      }
    }

    if (totalShares <= 0.00001) {
      await _deleteHolding(symbol);
    } else {
      await _upsertHolding(Holding(
        id: _uuid.v4(),
        symbol: symbol,
        name: name,
        type: _inferType(symbol),
        currency: currency,
        shares: totalShares,
        avgCost: totalCost / totalShares,
      ));
    }
  }

  String _inferType(String symbol) {
    final s = symbol.toUpperCase();
    if (s.endsWith('-USD') || s.endsWith('-EUR') ||
        ['BTC', 'ETH', 'SOL', 'ADA', 'XRP', 'BNB', 'DOGE'].contains(s)) return 'crypto';
    return 'stock';
  }

  // ── Watchlist ─────────────────────────────────────────────────────────────

  Future<List<WatchlistItem>> getWatchlist() async {
    final rows = await _sb.from('watchlist').select().eq('user_id', _uid);
    return rows.map((r) => WatchlistItem.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> addToWatchlist(WatchlistItem item) async {
    await _sb.from('watchlist').upsert(
      {...item.toJson(), 'user_id': _uid},
      onConflict: 'user_id,symbol',
    );
  }

  Future<void> removeFromWatchlist(String id) async {
    await _sb.from('watchlist').delete().eq('id', id).eq('user_id', _uid);
  }

  static String newId() => _uuid.v4();
}
