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
    // Show masked token if already set
    if (GhDbService().hasToken) {
      _tokenCtrl.text = '••••••••••••••••••••';
    }
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
      // Validate token with a test read
      await GhDbService().saveToken(token);
      await GhDbService().readList('users.json');
      if (mounted) context.go('/login');
    } catch (e) {
      await GhDbService().clearToken();
      setState(() {
        _error = 'Token non valido o repo non accessibile.\nVerifica che il token abbia scope "repo".';
        _saving = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    await GhDbService().clearToken();
    if (mounted) context.go('/setup');
  }

  @override
  Widget build(BuildContext context) {
    final fromLogin = GoRouterState.of(context).matchedLocation == '/setup';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token GitHub'),
        leading: fromLogin ? null : const BackButton(),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.key_rounded, color: kYellow, size: 48),
                const SizedBox(height: 16),
                const Text('Configura accesso GitHub',
                    style: TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Stonks usa un repository GitHub privato come database.\n'
                  'Genera un Personal Access Token (classic) con scope "repo" e incollalo qui.',
                  style: TextStyle(color: kMuted, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  text: 'github.com → Settings → Developer settings → Personal access tokens → Tokens (classic)',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: _obscure,
                  onTap: () {
                    if (_tokenCtrl.text.startsWith('•')) _tokenCtrl.clear();
                  },
                  decoration: InputDecoration(
                    labelText: 'GitHub Personal Access Token',
                    hintText: 'ghp_...',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: kMuted),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kRed.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Salva e continua'),
                ),
                if (!fromLogin) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _logout,
                      child: const Text('Esci e resetta token', style: TextStyle(color: kRed)),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _ScopeHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String text;
  const _InfoRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_right_alt, color: kBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: kMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _ScopeHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Scope richiesto:', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _ScopeChip(label: 'repo', description: 'Accesso completo ai repo privati'),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final String description;
  const _ScopeChip({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: kGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: kGreen.withValues(alpha: 0.4)),
          ),
          child: Text(label, style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Text(description, style: const TextStyle(color: kMuted, fontSize: 12)),
      ],
    );
  }
}
