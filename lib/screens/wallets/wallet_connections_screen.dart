import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/wallet_connection.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_theme.dart';

class WalletConnectionsScreen extends StatefulWidget {
  const WalletConnectionsScreen({super.key});

  @override
  State<WalletConnectionsScreen> createState() => _WalletConnectionsScreenState();
}

class _WalletConnectionsScreenState extends State<WalletConnectionsScreen> {
  late Future<List<WalletConnection>> _walletsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _walletsFuture = WalletService().getWallets());

  Future<void> _delete(String id) async {
    await WalletService().removeWallet(id);
    _load();
  }

  Future<void> _sync(WalletConnection w) async {
    final snack = ScaffoldMessenger.of(context);
    try {
      final balances = await WalletService().fetchBalance(w);
      if (!mounted) return;
      final text = balances.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(6)}').join('\n');
      snack.showSnackBar(SnackBar(content: Text(text.isEmpty ? 'Nessun saldo' : text)));
    } catch (e) {
      snack.showSnackBar(SnackBar(content: Text('Errore: $e'), backgroundColor: kRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet & Exchange')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: kSurface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _AddWalletSheet(onAdded: _load),
          );
        },
      ),
      body: FutureBuilder<List<WalletConnection>>(
        future: _walletsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Errore: ${snap.error}', style: const TextStyle(color: kRed)));
          }
          final wallets = snap.data ?? [];
          if (wallets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: kMuted, size: 48),
                  const SizedBox(height: 12),
                  const Text('Nessun wallet collegato', style: TextStyle(color: kMuted)),
                  const SizedBox(height: 6),
                  const Text('Aggiungi exchange o indirizzi crypto', style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            );
          }

          final exchanges = wallets.where((w) => w.type == 'exchange').toList();
          final addresses = wallets.where((w) => w.type == 'address').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (exchanges.isNotEmpty) ...[
                _SectionHeader('Exchange API'),
                ...exchanges.map((w) => _WalletTile(wallet: w, onDelete: _delete, onSync: _sync)),
                const SizedBox(height: 16),
              ],
              if (addresses.isNotEmpty) ...[
                _SectionHeader('Indirizzi wallet'),
                ...addresses.map((w) => _WalletTile(wallet: w, onDelete: _delete, onSync: _sync)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(color: kMuted, fontSize: 11, letterSpacing: 1.1)),
      );
}

class _WalletTile extends StatelessWidget {
  final WalletConnection wallet;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(WalletConnection w) onSync;
  const _WalletTile({required this.wallet, required this.onDelete, required this.onSync});

  String get _subtitle {
    if (wallet.type == 'exchange') return wallet.exchange ?? '';
    return _short(wallet.address ?? '');
  }

  String _short(String s) => s.length > 20 ? '${s.substring(0, 10)}…${s.substring(s.length - 8)}' : s;

  IconData get _icon {
    switch (wallet.exchange ?? wallet.chain) {
      case 'binance': return Icons.swap_horiz_rounded;
      case 'coinbase': return Icons.currency_bitcoin;
      case 'kraken': return Icons.water_rounded;
      case 'bitcoin': return Icons.currency_bitcoin;
      case 'ethereum': return Icons.diamond_outlined;
      case 'solana': return Icons.flash_on_rounded;
      default: return Icons.account_balance_wallet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: kBlue.withValues(alpha: 0.15),
          child: Icon(_icon, color: kBlue, size: 20),
        ),
        title: Text(wallet.name, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
        subtitle: Text(_subtitle, style: const TextStyle(color: kMuted, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: kGreen, size: 20),
              tooltip: 'Sincronizza',
              onPressed: () => onSync(wallet),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
              onPressed: () => onDelete(wallet.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add wallet bottom sheet ───────────────────────────────────────────────────

class _AddWalletSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddWalletSheet({required this.onAdded});
  @override
  State<_AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends State<_AddWalletSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _saving = false;
  String? _error;

  // Exchange
  String _exchange = 'binance';
  final _nameCtrl  = TextEditingController();
  final _keyCtrl   = TextEditingController();
  final _secCtrl   = TextEditingController();

  // Address
  String _chain = 'bitcoin';
  final _addrNameCtrl = TextEditingController();
  final _addrCtrl     = TextEditingController();

  static const _exchanges = ['binance', 'coinbase', 'kraken'];
  static const _chains    = ['bitcoin', 'ethereum', 'solana'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _secCtrl.dispose();
    _addrNameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      WalletConnection w;
      if (_tab.index == 0) {
        w = WalletConnection(
          id: WalletService.newId(),
          type: 'exchange',
          name: _nameCtrl.text.trim().isEmpty ? _exchange : _nameCtrl.text.trim(),
          exchange: _exchange,
          apiKey: _keyCtrl.text.trim(),
          apiSecret: _secCtrl.text.trim(),
        );
      } else {
        if (_addrCtrl.text.trim().isEmpty) throw Exception('Indirizzo obbligatorio');
        w = WalletConnection(
          id: WalletService.newId(),
          type: 'address',
          name: _addrNameCtrl.text.trim().isEmpty ? _chain : _addrNameCtrl.text.trim(),
          chain: _chain,
          address: _addrCtrl.text.trim(),
        );
      }
      await WalletService().addWallet(w);
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aggiungi connessione',
              style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TabBar(
            controller: _tab,
            tabs: const [Tab(text: 'Exchange API'), Tab(text: 'Indirizzo wallet')],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: TabBarView(
              controller: _tab,
              children: [
                _ExchangeForm(
                  exchange: _exchange,
                  exchanges: _exchanges,
                  nameCtrl: _nameCtrl,
                  keyCtrl: _keyCtrl,
                  secCtrl: _secCtrl,
                  onExchangeChanged: (v) => setState(() => _exchange = v),
                ),
                _AddressForm(
                  chain: _chain,
                  chains: _chains,
                  nameCtrl: _addrNameCtrl,
                  addrCtrl: _addrCtrl,
                  onChainChanged: (v) => setState(() => _chain = v),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }
}

class _ExchangeForm extends StatelessWidget {
  final String exchange;
  final List<String> exchanges;
  final TextEditingController nameCtrl, keyCtrl, secCtrl;
  final ValueChanged<String> onExchangeChanged;
  const _ExchangeForm({
    required this.exchange, required this.exchanges,
    required this.nameCtrl, required this.keyCtrl, required this.secCtrl,
    required this.onExchangeChanged,
  });

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          DropdownButtonFormField<String>(
            value: exchange,
            decoration: const InputDecoration(labelText: 'Exchange'),
            items: exchanges.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) { if (v != null) onExchangeChanged(v); },
          ),
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome (opzionale)')),
          const SizedBox(height: 10),
          TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'API Key'), inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
          const SizedBox(height: 10),
          TextField(controller: secCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'API Secret')),
        ],
      );
}

class _AddressForm extends StatelessWidget {
  final String chain;
  final List<String> chains;
  final TextEditingController nameCtrl, addrCtrl;
  final ValueChanged<String> onChainChanged;
  const _AddressForm({
    required this.chain, required this.chains,
    required this.nameCtrl, required this.addrCtrl,
    required this.onChainChanged,
  });

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          DropdownButtonFormField<String>(
            value: chain,
            decoration: const InputDecoration(labelText: 'Blockchain'),
            items: chains.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) { if (v != null) onChainChanged(v); },
          ),
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Label (opzionale)')),
          const SizedBox(height: 10),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Indirizzo'), inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
        ],
      );
}
