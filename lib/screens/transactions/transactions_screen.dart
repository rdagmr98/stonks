import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';
import '../../services/portfolio_service.dart';
import '../../theme/app_theme.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');
final _moneyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transazioni')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-transaction'),
        backgroundColor: kPrimary,
        child: const Icon(Icons.add),
      ),
      body: txAsync.when(
        data: (txs) => txs.isEmpty
            ? const Center(child: Text('Nessuna transazione', style: TextStyle(color: kMuted)))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(transactionsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: txs.length,
                  itemBuilder: (context, i) => _TxTile(tx: txs[i], ref: ref),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: kRed))),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final StTransaction tx;
  final WidgetRef ref;
  const _TxTile({required this.tx, required this.ref});

  Color get _typeColor {
    switch (tx.type) {
      case 'buy': return kGreen;
      case 'sell': return kRed;
      case 'dividend': return kYellow;
      default: return kMuted;
    }
  }

  IconData get _typeIcon {
    switch (tx.type) {
      case 'buy': return Icons.arrow_downward;
      case 'sell': return Icons.arrow_upward;
      case 'dividend': return Icons.payments_outlined;
      default: return Icons.swap_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(tx.id),
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
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kCard,
            title: const Text('Elimina transazione'),
            content: Text('Elimina ${tx.type} ${tx.symbol} del ${_dateFmt.format(tx.date)}?'),
            actions: [
              TextButton(onPressed: () => ctx.pop(false), child: const Text('Annulla')),
              TextButton(
                onPressed: () => ctx.pop(true),
                child: const Text('Elimina', style: TextStyle(color: kRed)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await PortfolioService().deleteTransaction(tx.id, tx.symbol, tx.name, tx.currency);
        ref.invalidate(transactionsProvider);
        ref.invalidate(holdingsProvider);
        ref.invalidate(portfolioSummaryProvider);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 20),
          ),
          title: Row(
            children: [
              Text(tx.symbol, style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tx.type.toUpperCase(),
                    style: TextStyle(color: _typeColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          subtitle: Text(
            '${tx.shares} pz @ ${_moneyFmt.format(tx.price)} · ${_dateFmt.format(tx.date)}',
            style: const TextStyle(color: kMuted, fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_moneyFmt.format(tx.total),
                  style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
              if (tx.fees > 0)
                Text('fee ${_moneyFmt.format(tx.fees)}',
                    style: const TextStyle(color: kMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
