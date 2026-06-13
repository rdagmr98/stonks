import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/holding_tile.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider);
    final quotes = ref.watch(allQuotesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Portafoglio')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-transaction'),
        backgroundColor: kPrimary,
        child: const Icon(Icons.add),
      ),
      body: holdings.when(
        data: (h) {
          if (h.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pie_chart_outline, color: kMuted, size: 56),
                  SizedBox(height: 12),
                  Text('Portafoglio vuoto', style: TextStyle(color: kMuted)),
                  SizedBox(height: 4),
                  Text('Aggiungi una transazione per iniziare.',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            );
          }
          final qs = quotes.asData?.value ?? {};
          // Sort by value desc
          final sorted = [...h]..sort((a, b) {
              final va = a.shares * (qs[a.symbol]?.price ?? a.avgCost);
              final vb = b.shares * (qs[b.symbol]?.price ?? b.avgCost);
              return vb.compareTo(va);
            });
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(holdingsProvider);
              ref.invalidate(allQuotesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: HoldingTile(holding: sorted[i], quote: qs[sorted[i].symbol]),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: kRed))),
      ),
    );
  }
}
