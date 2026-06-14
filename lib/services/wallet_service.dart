import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/wallet_connection.dart';
import 'gh_db_service.dart';

const _uuid = Uuid();

// Per ogni exchange: balance fetch con HMAC lato client
class WalletService {
  static final WalletService _instance = WalletService._();
  factory WalletService() => _instance;
  WalletService._();

  final _db = GhDbService();

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<List<WalletConnection>> getWallets() async {
    final (list, _) = await _db.readList('wallets.json');
    return list.map((e) => WalletConnection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addWallet(WalletConnection w) async {
    final (list, sha) = await _db.readList('wallets.json');
    list.add(w.toJson());
    await _db.writeList('wallets.json', list, sha: sha);
  }

  Future<void> removeWallet(String id) async {
    final (list, sha) = await _db.readList('wallets.json');
    list.removeWhere((e) => (e as Map)['id'] == id);
    await _db.writeList('wallets.json', list, sha: sha);
    _db.invalidate('wallets.json');
  }

  static String newId() => _uuid.v4();

  // ── Balance fetch ────────────────────────────────────────────────────────

  Future<Map<String, double>> fetchBalance(WalletConnection w) async {
    if (w.type == 'address') return _fetchAddressBalance(w);
    if (w.type == 'exchange') return _fetchExchangeBalance(w);
    return {};
  }

  // Indirizzi pubblici — no auth
  Future<Map<String, double>> _fetchAddressBalance(WalletConnection w) async {
    switch (w.chain) {
      case 'bitcoin':
        return _btcBalance(w.address!);
      case 'ethereum':
        return _ethBalance(w.address!);
      case 'solana':
        return _solBalance(w.address!);
      default:
        return {};
    }
  }

  Future<Map<String, double>> _btcBalance(String address) async {
    final res = await http.get(Uri.parse('https://blockstream.info/api/address/$address'));
    if (res.statusCode != 200) throw Exception('BTC: ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final funded = (j['chain_stats']['funded_txo_sum'] as int?) ?? 0;
    final spent  = (j['chain_stats']['spent_txo_sum']  as int?) ?? 0;
    return {'BTC': (funded - spent) / 1e8};
  }

  Future<Map<String, double>> _ethBalance(String address) async {
    final url = 'https://api.etherscan.io/api?module=account&action=balance&address=$address&tag=latest&apikey=YourApiKeyToken';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('ETH: ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final wei = double.tryParse(j['result'] as String? ?? '0') ?? 0;
    return {'ETH': wei / 1e18};
  }

  Future<Map<String, double>> _solBalance(String address) async {
    final res = await http.post(
      Uri.parse('https://api.mainnet-beta.solana.com'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'getBalance', 'params': [address]}),
    );
    if (res.statusCode != 200) throw Exception('SOL: ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final lamports = (j['result']?['value'] as int?) ?? 0;
    return {'SOL': lamports / 1e9};
  }

  // Exchange con HMAC client-side
  Future<Map<String, double>> _fetchExchangeBalance(WalletConnection w) async {
    switch (w.exchange) {
      case 'binance':
        return _binanceBalance(w.apiKey!, w.apiSecret!);
      case 'coinbase':
        return _coinbaseBalance(w.apiKey!, w.apiSecret!);
      case 'kraken':
        return _krakenBalance(w.apiKey!, w.apiSecret!);
      default:
        return {};
    }
  }

  // ── HMAC helpers ─────────────────────────────────────────────────────────

  static String _hmac256hex(String secret, String message) {
    final key = utf8.encode(secret);
    final msg = utf8.encode(message);
    return Hmac(sha256, key).convert(msg).toString();
  }

  static String _hmac512b64(List<int> secretBytes, List<int> messageBytes) {
    final mac = Hmac(sha512, secretBytes).convert(messageBytes);
    return base64.encode(mac.bytes);
  }

  // ── Binance ───────────────────────────────────────────────────────────────

  Future<Map<String, double>> _binanceBalance(String key, String secret) async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final query = 'timestamp=$ts';
    final sig = _hmac256hex(secret, query);
    final res = await http.get(
      Uri.parse('https://api.binance.com/api/v3/account?$query&signature=$sig'),
      headers: {'X-MBX-APIKEY': key},
    );
    if (res.statusCode != 200) throw Exception('Binance: ${res.statusCode}');
    final balances = (jsonDecode(res.body)['balances'] as List)
        .cast<Map<String, dynamic>>();
    final skip = {'USDT', 'USDC', 'BUSD', 'EUR', 'USD'};
    return {
      for (final b in balances)
        if (!skip.contains(b['asset']))
          if ((double.tryParse(b['free'] as String? ?? '0') ?? 0) +
                  (double.tryParse(b['locked'] as String? ?? '0') ?? 0) >
              0)
            b['asset'] as String:
                (double.tryParse(b['free'] as String? ?? '0') ?? 0) +
                    (double.tryParse(b['locked'] as String? ?? '0') ?? 0),
    };
  }

  // ── Coinbase (v2 accounts) ────────────────────────────────────────────────

  Future<Map<String, double>> _coinbaseBalance(String key, String secret) async {
    const path = '/v2/accounts?limit=100';
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sig = _hmac256hex(secret, '${ts}GET$path');
    final res = await http.get(
      Uri.parse('https://api.coinbase.com$path'),
      headers: {
        'CB-ACCESS-KEY': key,
        'CB-ACCESS-SIGN': sig,
        'CB-ACCESS-TIMESTAMP': ts,
      },
    );
    if (res.statusCode != 200) throw Exception('Coinbase: ${res.statusCode}');
    final accounts = (jsonDecode(res.body)['data'] as List)
        .cast<Map<String, dynamic>>();
    return {
      for (final a in accounts)
        if ((double.tryParse(a['balance']['amount'] as String? ?? '0') ?? 0) > 0)
          a['currency']['code'] as String:
              double.tryParse(a['balance']['amount'] as String? ?? '0') ?? 0,
    };
  }

  // ── Kraken (HMAC-SHA512) ──────────────────────────────────────────────────

  Future<Map<String, double>> _krakenBalance(String key, String secret) async {
    const path = '/0/private/Balance';
    final nonce = DateTime.now().millisecondsSinceEpoch.toString();
    final body = 'nonce=$nonce';
    final secretBytes = base64.decode(secret);
    final sha256Bytes = sha256.convert(utf8.encode(nonce + body)).bytes;
    final message = Uint8List.fromList(utf8.encode(path) + sha256Bytes);
    final sign = _hmac512b64(secretBytes, message);
    final res = await http.post(
      Uri.parse('https://api.kraken.com$path'),
      headers: {'API-Key': key, 'API-Sign': sign, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode != 200) throw Exception('Kraken: ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if ((data['error'] as List).isNotEmpty) throw Exception('Kraken: ${data['error']}');
    final result = data['result'] as Map<String, dynamic>;
    const fiat = {'ZUSD', 'ZEUR', 'ZGBP', 'ZJPY', 'ZCAD'};
    final assetMap = {'XXBT': 'BTC', 'XETH': 'ETH', 'XXRP': 'XRP', 'XLTC': 'LTC'};
    return {
      for (final e in result.entries)
        if (!fiat.contains(e.key))
          if ((double.tryParse(e.value as String? ?? '0') ?? 0) > 0)
            (assetMap[e.key] ?? (e.key.startsWith('X') || e.key.startsWith('Z') ? e.key.substring(1) : e.key)):
                double.tryParse(e.value as String? ?? '0') ?? 0,
    };
  }
}
