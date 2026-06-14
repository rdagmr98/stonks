import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _sb = Supabase.instance.client;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> loadCurrentUser() async {
    final user = _sb.auth.currentUser;
    if (user == null) { _currentUser = null; return; }
    final profile = await _sb.from('profiles').select().eq('id', user.id).maybeSingle();
    if (profile == null) { _currentUser = null; return; }
    _currentUser = AppUser.fromProfile(profile, user.email ?? '');
  }

  Future<String?> login(String email, String password) async {
    try {
      await _sb.auth.signInWithPassword(email: email, password: password);
      await loadCurrentUser();
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> register(String email, String password, String username) async {
    try {
      await _sb.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      await loadCurrentUser();
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    await _sb.auth.signOut();
    _currentUser = null;
  }

  Future<bool> tryAutoLogin() async {
    await loadCurrentUser();
    return _currentUser != null;
  }
}
