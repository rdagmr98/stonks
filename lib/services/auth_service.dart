import 'dart:convert';
import 'package:crypto/crypto.dart' show sha256;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'gh_db_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _db = GhDbService();
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  Future<bool> login(String username, String password) async {
    try {
      final (list, _) = await _db.readList('users.json');
      final hash = _hash(password);
      final match = list
          .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .where((u) => u.username == username && u.passwordHash == hash)
          .firstOrNull;
      if (match == null) return false;
      _currentUser = match;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', match.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    _db.invalidateAll();
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('current_user_id');
    if (id == null) return false;
    try {
      final (list, _) = await _db.readList('users.json');
      _currentUser = list
          .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .where((u) => u.id == id)
          .firstOrNull;
      return _currentUser != null;
    } catch (_) {
      return false;
    }
  }

  static String hashPassword(String password) => _hash(password);
}
