import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Proxy via Cloudflare Worker — no GitHub token in the Flutter bundle.
// Bearer = sha256(password), verified server-side.
class GhDbService {
  static const _workerUrl = String.fromEnvironment(
    'WORKER_URL',
    defaultValue: 'https://stonks-worker.rdagmr98.workers.dev',
  );
  static const _prefKey = 'worker_bearer';

  static final GhDbService _instance = GhDbService._();
  factory GhDbService() => _instance;
  GhDbService._();

  String? _bearer;
  final Map<String, dynamic> _cache = {};

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _bearer = prefs.getString(_prefKey);
  }

  Future<void> setBearer(String bearer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, bearer);
    _bearer = bearer;
    _cache.clear();
  }

  Future<void> clearBearer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    _bearer = null;
    _cache.clear();
  }

  // Keep backward-compat names used in auth_service / settings_screen
  Future<void> saveToken(String t) => setBearer(t);
  Future<void> clearToken() => clearBearer();
  bool get hasToken => _bearer != null && _bearer!.isNotEmpty;

  Map<String, String> get _headers {
    if (_bearer == null || _bearer!.isEmpty) throw Exception('Non autenticato');
    return {
      'Authorization': 'Bearer $_bearer',
      'Content-Type': 'application/json',
    };
  }

  String _url(String file) => '$_workerUrl/api/data/$file';

  Future<(List<dynamic>, String)> readList(String file) async {
    if (_cache.containsKey(file)) {
      final c = _cache[file]!;
      return (c['data'] as List<dynamic>, c['sha'] as String);
    }
    final res = await http.get(Uri.parse(_url(file)), headers: _headers);
    if (res.statusCode == 404) return (<dynamic>[], '');
    if (res.statusCode != 200) throw Exception('Backend read $file: ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sha = (body['sha'] as String?) ?? '';
    final rawContent = (body['content'] as String).replaceAll('\n', '');
    final content = utf8.decode(base64.decode(rawContent));
    final data = jsonDecode(content) as List<dynamic>;
    _cache[file] = {'data': data, 'sha': sha};
    return (data, sha);
  }

  Future<void> writeList(String file, List<dynamic> data, {String sha = ''}) async {
    final content = base64.encode(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    final body = jsonEncode({
      'content': content,
      if (sha.isNotEmpty) 'sha': sha,
    });

    for (int attempt = 0; attempt < 3; attempt++) {
      final res = await http.put(Uri.parse(_url(file)), headers: _headers, body: body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final respBody = jsonDecode(res.body) as Map<String, dynamic>;
        final respSha = ((respBody['content'] as Map?)?['sha'] as String?) ?? sha;
        _cache[file] = {'data': data, 'sha': respSha};
        return;
      }
      if (res.statusCode == 409 && attempt < 2) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        invalidate(file);
        final (_, freshSha) = await readList(file);
        final retryBody = jsonEncode({
          'content': content,
          if (freshSha.isNotEmpty) 'sha': freshSha,
        });
        final r2 = await http.put(Uri.parse(_url(file)), headers: _headers, body: retryBody);
        if (r2.statusCode == 200 || r2.statusCode == 201) {
          final rb = jsonDecode(r2.body) as Map<String, dynamic>;
          _cache[file] = {'data': data, 'sha': ((rb['content'] as Map?)?['sha'] as String?) ?? ''};
          return;
        }
        continue;
      }
      throw Exception('Backend write $file: ${res.statusCode} ${res.body}');
    }
  }

  void invalidate(String file) => _cache.remove(file);
  void invalidateAll() => _cache.clear();
}
