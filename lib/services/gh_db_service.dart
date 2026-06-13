import 'dart:convert';
import 'package:http/http.dart' as http;

class GhDbService {
  static const _owner = 'rdagmr98';
  static const _repo = 'stonks-data';
  static const _branch = 'main';
  static const _token = String.fromEnvironment('GH_TOKEN');

  static final GhDbService _instance = GhDbService._();
  factory GhDbService() => _instance;
  GhDbService._();

  final Map<String, dynamic> _cache = {};

  Map<String, String> get _headers => {
        'Authorization': 'token $_token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      };

  String _url(String file) =>
      'https://api.github.com/repos/$_owner/$_repo/contents/$file?ref=$_branch';

  Future<(List<dynamic>, String)> readList(String file) async {
    if (_cache.containsKey(file)) {
      final c = _cache[file]!;
      return (c['data'] as List<dynamic>, c['sha'] as String);
    }
    final res = await http.get(Uri.parse(_url(file)), headers: _headers);
    if (res.statusCode == 404) return (<dynamic>[], '');
    if (res.statusCode != 200) throw Exception('GH read $file: ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final sha = body['sha'] as String;
    final content = utf8.decode(base64.decode((body['content'] as String).replaceAll('\n', '')));
    final data = jsonDecode(content) as List<dynamic>;
    _cache[file] = {'data': data, 'sha': sha};
    return (data, sha);
  }

  Future<void> writeList(String file, List<dynamic> data, {String sha = ''}) async {
    final content = base64.encode(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
    final body = jsonEncode({
      'message': 'update $file',
      'content': content,
      'branch': _branch,
      if (sha.isNotEmpty) 'sha': sha,
    });

    for (int attempt = 0; attempt < 3; attempt++) {
      final res = await http.put(Uri.parse(_url(file)), headers: _headers, body: body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final respSha = (jsonDecode(res.body)['content']['sha']) as String;
        _cache[file] = {'data': data, 'sha': respSha};
        return;
      }
      if (res.statusCode == 409 && attempt < 2) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        final (_, freshSha) = await readList(file);
        // retry with updated sha
        final retryBody = jsonEncode({
          'message': 'update $file',
          'content': content,
          'branch': _branch,
          if (freshSha.isNotEmpty) 'sha': freshSha,
        });
        final r2 = await http.put(Uri.parse(_url(file)), headers: _headers, body: retryBody);
        if (r2.statusCode == 200 || r2.statusCode == 201) {
          _cache[file] = {'data': data, 'sha': (jsonDecode(r2.body)['content']['sha']) as String};
          return;
        }
        continue;
      }
      throw Exception('GH write $file: ${res.statusCode} ${res.body}');
    }
  }

  void invalidate(String file) => _cache.remove(file);
  void invalidateAll() => _cache.clear();
}
