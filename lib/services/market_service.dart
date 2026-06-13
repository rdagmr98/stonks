import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quote.dart';

class MarketService {
  static final MarketService _instance = MarketService._();
  factory MarketService() => _instance;
  MarketService._();

  final Map<String, (Quote, DateTime)> _cache = {};
  static const _ttl = Duration(minutes: 5);

  Future<Quote?> fetchQuote(String symbol) async {
    final now = DateTime.now();
    if (_cache.containsKey(symbol)) {
      final (q, t) = _cache[symbol]!;
      if (now.difference(t) < _ttl) return q;
    }
    try {
      final uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d',
        );
      final res = await http.get(uri, headers: {'User-Agent': 'Mozilla/5.0'});
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final meta = body['chart']['result'][0]['meta'] as Map<String, dynamic>;
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num? ?? price).toDouble();
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
      _cache[symbol] = (quote, now);
      return quote;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Quote?>> fetchQuotes(List<String> symbols) async {
    final results = await Future.wait(symbols.map(fetchQuote));
    return {for (var i = 0; i < symbols.length; i++) symbols[i]: results[i]};
  }

  // EUR/USD exchange rate for currency conversion
  Future<double> getExchangeRate(String from, String to) async {
    if (from == to) return 1.0;
    final q = await fetchQuote('${from}${to}=X'); // ignore: unnecessary_brace_in_string_interps
    return q?.price ?? 1.0;
  }
}
