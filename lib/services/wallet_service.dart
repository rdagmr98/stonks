import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet_connection.dart';

const _uuid = Uuid();

class WalletService {
  static final WalletService _instance = WalletService._();
  factory WalletService() => _instance;
  WalletService._();

  final _sb = Supabase.instance.client;
  String get _uid => _sb.auth.currentUser!.id;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<List<WalletConnection>> getWallets() async {
    final rows = await _sb.from('wallet_connections').select().eq('user_id', _uid);
    return rows.map((r) => WalletConnection.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> addWallet(WalletConnection w) async {
    await _sb.from('wallet_connections').insert({...w.toJson(), 'user_id': _uid});
  }

  Future<void> removeWallet(String id) async {
    await _sb.from('wallet_connections').delete().eq('id', id).eq('user_id', _uid);
  }

  static String newId() => _uuid.v4();

  // ── Balance fetch ─────────────────────────────────────────────────────────

  Future<Map<String, double>> fetchBalance(WalletConnection w) async {
    if (w.type == 'address')  return _fetchAddressBalance(w);
    if (w.type == 'exchange') return _fetchExchangeBalance(w);
    return {};
  }

  Future<Map<String, double>> _fetchAddressBalance(WalletConnection w) async {
    switch (w.chain) {
      case 'bitcoin':  return _btcBalance(w.address!);
      case 'ethereum': return _ethBalance(w.address!);
      case 'solana':   return _solBalance(w.address!);
      default: return {};
    }
  }

  Future<Map<String, double>> _btcBalance(String address) async {
    final res = await http.get(Uri.parse('https://blockstream.info/api/address/$address'));
    if (res.statusCode != 200) throw Exception('BTC ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final funded = (j['chain_stats']['funded_txo_sum'] as int?) ?? 0;
    final spent  = (j['chain_stats']['spent_txo_sum']  as int?) ?? 0;
    return {'BTC': (funded - spent) / 1e8};
  }

  Future<Map<String, double>> _ethBalance(String address) async {
    final res = await http.get(Uri.parse(
      'https://api.etherscan.io/api?module=account&action=balance&address=$address&tag=latest&apikey=YourApiKeyToken',
    ));
    if (res.statusCode != 200) throw Exception('ETH ${res.statusCode}');
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
    if (res.statusCode != 200) throw Exception('SOL ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final lamports = (j['result']?['value'] as int?) ?? 0;
    return {'SOL': lamports / 1e9};
  }

  Future<Map<String, double>> _fetchExchangeBalance(WalletConnection w) async {
    switch (w.exchange) {
      case 'binance':  return _binanceBalance(w.apiKey!, w.apiSecret!);
      case 'coinbase': return _coinbaseBalance(w.apiKey!, w.apiSecret!);
      case 'kraken':   return _krakenBalance(w.apiKey!, w.apiSecret!);
      default: return {};
    }
  }

  static String _hmac256hex(String secret, String message) =>
      Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(message)).toString();

  static String _hmac512b64(List<int> secretBytes, List<int> messageBytes) =>
      base64.encode(Hmac(sha512, secretBytes).convert(messageBytes).bytes);

  Future<Map<String, double>> _binanceBalance(String key, String secret) async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final query = 'timestamp=$ts';
    final sig = _hmac256hex(secret, query);
    final res = await http.get(
      Uri.parse('https://api.binance.com/api/v3/account?$query&signature=$sig'),
      headers: {'X-MBX-APIKEY': key},
    );
    if (res.statusCode != 200) throw Exception('Binance ${res.statusCode}');
    final skip = {'USDT', 'USDC', 'BUSD', 'EUR', 'USD'};
    return {
      for (final b in (jsonDecode(res.body)['balances'] as List).cast<Map<String, dynamic>>())
        if (!skip.contains(b['asset']))
          if ((double.tryParse(b['free'] ?? '0') ?? 0) + (double.tryParse(b['locked'] ?? '0') ?? 0) > 0)
            b['asset'] as String:
                (double.tryParse(b['free'] ?? '0') ?? 0) + (double.tryParse(b['locked'] ?? '0') ?? 0),
    };
  }

  Future<Map<String, double>> _coinbaseBalance(String key, String secret) async {
    const path = '/v2/accounts?limit=100';
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sig = _hmac256hex(secret, '${ts}GET$path');
    final res = await http.get(
      Uri.parse('https://api.coinbase.com$path'),
      headers: {'CB-ACCESS-KEY': key, 'CB-ACCESS-SIGN': sig, 'CB-ACCESS-TIMESTAMP': ts},
    );
    if (res.statusCode != 200) throw Exception('Coinbase ${res.statusCode}');
    return {
      for (final a in (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>())
        if ((double.tryParse(a['balance']['amount'] ?? '0') ?? 0) > 0)
          a['currency']['code'] as String: double.tryParse(a['balance']['amount'] ?? '0') ?? 0,
    };
  }

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
    if (res.statusCode != 200) throw Exception('Kraken ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if ((data['error'] as List).isNotEmpty) throw Exception('Kraken: ${data['error']}');
    const fiat = {'ZUSD', 'ZEUR', 'ZGBP', 'ZJPY', 'ZCAD'};
    const assetMap = {'XXBT': 'BTC', 'XETH': 'ETH', 'XXRP': 'XRP', 'XLTC': 'LTC'};
    return {
      for (final e in (data['result'] as Map<String, dynamic>).entries)
        if (!fiat.contains(e.key) && (double.tryParse(e.value ?? '0') ?? 0) > 0)
          (assetMap[e.key] ?? (e.key.startsWith('X') || e.key.startsWith('Z') ? e.key.substring(1) : e.key)):
              double.tryParse(e.value ?? '0') ?? 0,
    };
  }
}
