import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _Section(
            title: 'Account',
            children: [
              _InfoTile(
                icon: Icons.person_rounded,
                label: 'Utente',
                value: user?.username ?? '—',
              ),
              _InfoTile(
                icon: Icons.shield_rounded,
                label: 'Ruolo',
                value: user?.role ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'Exchange collegati',
            children: const [
              _ExchangeTile(name: 'Coinbase', icon: Icons.currency_bitcoin),
              _ExchangeTile(name: 'Binance', icon: Icons.swap_horiz_rounded),
              _ExchangeTile(name: 'Kraken', icon: Icons.water_rounded),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Esci'),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(color: kMuted, fontSize: 11, letterSpacing: 1.2)),
        ),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kBlue, size: 20),
      title: Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
      trailing: Text(value, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
    );
  }
}

class _ExchangeTile extends StatelessWidget {
  final String name;
  final IconData icon;
  const _ExchangeTile({required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kMuted, size: 20),
      title: Text(name, style: const TextStyle(color: kText, fontSize: 14)),
      trailing: const Text('API key via worker', style: TextStyle(color: kMuted, fontSize: 11)),
    );
  }
}
