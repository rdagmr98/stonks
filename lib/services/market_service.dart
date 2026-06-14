import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quote.dart';

class PricePoint {
  final DateTime date;
  final double close;
  const PricePoint(this.date, this.close);
}

class MarketService {
  static final MarketService _instance = MarketService._();
  factory MarketService() => _instance;
  MarketService._();

  final Map<String, (Quote, DateTime)> _quoteCache = {};
  final Map<String, (List<PricePoint>, DateTime)> _historyCache = {};
  final Map<String, double> _fxCache = {};

  static const _quoteTtl = Duration(minutes: 5);
  static const _historyTtl = Duration(minutes: 30);
  static const _fxTtl = Duration(hours: 1);

  static const _headers = {'User-Agent': 'Mozilla/5.0'};

  Future<Quote?> fetchQuote(String symbol) async {
    final now = DateTime.now();
    if (_quoteCache.containsKey(symbol)) {
      final (q, t) = _quoteCache[symbol]!;
      if (now.difference(t) < _quoteTtl) return q;
    }
    try {
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final result = body['chart']['result'];
      if (result == null || (result as List).isEmpty) return null;
      final meta = result[0]['meta'] as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final prevClose =
          (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num? ?? price)
              .toDouble();
      final change = price - prevClose;
      final changePct = prevClose != 0 ? change / prevClose * 100 : 0.0;
      final quote = Quote(
        symbol: symbol,
        price: price,
        change: change,
        changePercent: changePct,
        currency: meta['currency'] as String? ?? 'USD',
        fetchedAt: now,
      );
      _quoteCache[symbol] = (quote, now);
      return quote;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Quote?>> fetchQuotes(List<String> symbols) async {
    final results = await Future.wait(symbols.map(fetchQuote));
    return {for (var i = 0; i < symbols.length; i++) symbols[i]: results[i]};
  }

  Future<List<PricePoint>> fetchHistory(String symbol, String range) async {
    final key = '$symbol|$range';
    final now = DateTime.now();
    if (_historyCache.containsKey(key)) {
      final (h, t) = _historyCache[key]!;
      if (now.difference(t) < _historyTtl) return h;
    }
    try {
      final interval = range == '1d' ? '5m' : range == '1wk' ? '30m' : '1d';
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=$interval&range=$range');
      final res = await http.get(uri, headers: _headers);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final result = body['chart']['result'];
      if (result == null || (result as List).isEmpty) return [];
      final timestamps = (result[0]['timestamp'] as List?)?.cast<int>() ?? [];
      final closes = (result[0]['indicators']['quote'][0]['close'] as List?)
              ?.map((v) => v == null ? null : (v as num).toDouble())
              .toList() ??
          [];
      final points = <PricePoint>[];
      for (var i = 0; i < timestamps.length && i < closes.length; i++) {
        if (closes[i] != null) {
          points.add(PricePoint(
            DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
            closes[i]!,
          ));
        }
      }
      _historyCache[key] = (points, now);
      return points;
    } catch (_) {
      return [];
    }
  }

  Future<double> getExchangeRate(String from, String to) async {
    if (from == to) return 1.0;
    final key = '$from$to';
    final cached = _fxCache[key];
    if (cached != null) return cached;
    final q = await fetchQuote('${from}${to}=X');
    final rate = q?.price ?? 1.0;
    _fxCache[key] = rate;
    return rate;
  }

  Future<Map<String, double>> getExchangeRates(List<String> currencies, String base) async {
    final unique = currencies.where((c) => c != base).toSet();
    final rates = await Future.wait(unique.map((c) => getExchangeRate(c, base)));
    final map = <String, double>{base: 1.0};
    for (var i = 0; i < unique.length; i++) {
      map[unique.elementAt(i)] = rates[i];
    }
    return map;
  }
}
