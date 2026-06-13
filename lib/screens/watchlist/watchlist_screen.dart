import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/watchlist_item.dart';
import '../../models/quote.dart';
import '../../providers/providers.dart';
import '../../services/portfolio_service.dart';
import '../../theme/app_theme.dart';

final _moneyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);
final _pct = NumberFormat('+#,##0.00;-#,##0.00', 'it_IT');

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchAsync = ref.watch(watchlistProvider);
    final quotes = ref.watch(allQuotesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Watchlist')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        backgroundColor: kPrimary,
        child: const Icon(Icons.add),
      ),
      body: watchAsync.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('Watchlist vuota', style: TextStyle(color: kMuted)))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(watchlistProvider);
                  ref.invalidate(allQuotesProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final q = quotes.asData?.value[items[i].symbol];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WatchTile(item: items[i], quote: q, ref: ref),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: kRed))),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final symCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String type = 'stock';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Aggiungi a watchlist',
                  style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(controller: symCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Simbolo *', hintText: 'MSFT')),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome', hintText: 'Microsoft Corp')),
              const SizedBox(height: 12),
              TextField(controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prezzo target (opzionale)')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (symCtrl.text.isEmpty) return;
                  final item = WatchlistItem(
                    id: const Uuid().v4(),
                    symbol: symCtrl.text.trim().toUpperCase(),
                    name: nameCtrl.text.trim().isEmpty ? symCtrl.text.trim().toUpperCase() : nameCtrl.text.trim(),
                    type: type,
                    targetPrice: double.tryParse(targetCtrl.text.replaceAll(',', '.')),
                  );
                  await PortfolioService().addToWatchlist(item);
                  ref.invalidate(watchlistProvider);
                  ref.invalidate(allQuotesProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Aggiungi'),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _WatchTile extends StatelessWidget {
  final WatchlistItem item;
  final Quote? quote;
  final WidgetRef ref;
  const _WatchTile({required this.item, required this.quote, required this.ref});

  @override
  Widget build(BuildContext context) {
    final price = quote?.price;
    final change = quote?.changePercent ?? 0;
    final pnlColor = change >= 0 ? kGreen : kRed;
    final atTarget = item.targetPrice != null && price != null && price >= item.targetPrice!;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha:0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: kRed),
      ),
      onDismissed: (_) async {
        await PortfolioService().removeFromWatchlist(item.id);
        ref.invalidate(watchlistProvider);
      },
      child: Card(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kBlue.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(item.symbol.substring(0, item.symbol.length.clamp(0, 3)),
                  style: const TextStyle(color: kBlue, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
          title: Row(
            children: [
              Text(item.symbol, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
              if (atTarget) ...[
                const SizedBox(width: 6),
                const Icon(Icons.flag, color: kGreen, size: 14),
              ],
            ],
          ),
          subtitle: Text(item.name, style: const TextStyle(color: kMuted, fontSize: 12)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price != null ? _moneyFmt.format(price) : '—',
                  style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
              Text('${_pct.format(change)}%', style: TextStyle(color: pnlColor, fontSize: 12)),
              if (item.targetPrice != null)
                Text('target ${_moneyFmt.format(item.targetPrice!)}',
                    style: TextStyle(color: atTarget ? kGreen : kMuted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
