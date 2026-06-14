import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (user != null) ...[
            const _SectionLabel('Account'),
            const SizedBox(height: 8),
            _InfoTile(icon: Icons.person_rounded,  label: 'Username', value: user.username),
            _InfoTile(icon: Icons.email_rounded,   label: 'Email',    value: user.email),
            _InfoTile(icon: Icons.euro_rounded,    label: 'Valuta',   value: user.currency),
            const SizedBox(height: 32),
          ],
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed)),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Esci'),
            onPressed: () => _logout(context),
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
