import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/gh_db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tokenCtrl = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (GhDbService().hasToken) _tokenCtrl.text = '••••••••••••••••••••';
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty || token.startsWith('•')) return;
    setState(() { _saving = true; _error = null; });
    try {
      await GhDbService().saveToken(token);
      await GhDbService().readList('users.json');
      if (mounted) context.go('/login');
    } catch (e) {
      await GhDbService().clearToken();
      setState(() {
        _error = 'Token non valido. Verifica che abbia scope "repo".';
        _saving = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    await GhDbService().clearToken();
    if (mounted) context.go('/setup');
  }

  bool get _fromSetup =>
      GoRouterState.of(context).matchedLocation == '/setup';

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(_fromSetup ? 'Configura accesso' : 'Impostazioni'),
        leading: _fromSetup ? null : const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Token section
          const _SectionLabel('GitHub Token'),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            obscureText: _obscure,
            onTap: () { if (_tokenCtrl.text.startsWith('•')) _tokenCtrl.clear(); },
            decoration: InputDecoration(
              hintText: 'ghp_... oppure github_pat_...',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: kMuted),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: kRed, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(GhDbService().hasToken ? 'Aggiorna token' : 'Salva e continua'),
          ),
          if (!_fromSetup) ...[
            const SizedBox(height: 32),
            // Account info
            if (user != null) ...[
              const _SectionLabel('Account'),
              const SizedBox(height: 8),
              _InfoTile(icon: Icons.person_rounded, label: 'Utente', value: user.username),
              _InfoTile(icon: Icons.euro_rounded, label: 'Valuta', value: user.currency),
              const SizedBox(height: 32),
            ],
            // Wallet connections
            const _SectionLabel('Exchange & Wallet'),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_rounded, color: kBlue),
              title: const Text('Connessioni wallet', style: TextStyle(color: kText)),
              subtitle: const Text('Coinbase, Binance, Kraken, indirizzi crypto', style: TextStyle(color: kMuted, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: kMuted),
              onTap: () => context.push('/wallets'),
            ),
            const SizedBox(height: 32),
            // Logout
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed)),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Esci'),
              onPressed: _logout,
            ),
          ],
          const SizedBox(height: 16),
          const _SectionLabel('Token GitHub — come ottenerlo'),
          const SizedBox(height: 6),
          const Text(
            'github.com → Settings → Developer settings → Personal access tokens → Tokens (classic) → scope "repo"',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(color: kMuted, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w600),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: kBlue, size: 18),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
            const Spacer(),
            Text(value, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
