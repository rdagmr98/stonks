import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/allocation_chart.dart';
import '../../widgets/holding_tile.dart';

final _fmt = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);
final _pct = NumberFormat('+#,##0.00;-#,##0.00', 'it_IT');

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final holdings = ref.watch(holdingsProvider);
    final quotes = ref.watch(allQuotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('stonks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(holdingsProvider);
              ref.invalidate(allQuotesProvider);
              ref.invalidate(portfolioSummaryProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(holdingsProvider);
          ref.invalidate(allQuotesProvider);
          ref.invalidate(portfolioSummaryProvider);
          await ref.read(portfolioSummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Portfolio value card
            summary.when(
              data: (s) => _PortfolioCard(summary: s),
              loading: () => const _SummaryShimmer(),
              error: (e, _) => _ErrorCard(error: e.toString()),
            ),
            const SizedBox(height: 16),
            // Allocation chart
            holdings.when(
              data: (h) => quotes.when(
                data: (q) => h.isEmpty ? const SizedBox() : AllocationChart(holdings: h, quotes: q),
                loading: () => const SizedBox(height: 200),
                error: (_, __) => const SizedBox(),
              ),
              loading: () => const SizedBox(height: 200),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 16),
            // Holdings list
            const Text('Portafoglio', style: TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            holdings.when(
              data: (h) => h.isEmpty
                  ? const _EmptyPortfolio()
                  : Column(
                      children: h.map((holding) {
                        final q = quotes.asData?.value[holding.symbol];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: HoldingTile(holding: holding, quote: q),
                        );
                      }).toList(),
                    ),
              loading: () => Column(
                children: List.generate(3, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _TileShimmer(),
                )),
              ),
              error: (e, _) => _ErrorCard(error: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final PortfolioSummary summary;
  const _PortfolioCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final pnlColor = summary.totalPnl >= 0 ? kGreen : kRed;
    final dayColor = summary.dailyChange >= 0 ? kGreen : kRed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Valore portafoglio', style: TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_fmt.format(summary.totalValue),
                style: const TextStyle(color: kText, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _Badge(
                  label: 'Oggi',
                  value: '${summary.dailyChange >= 0 ? '+' : ''}${_fmt.format(summary.dailyChange)} (${_pct.format(summary.dailyChangePct)}%)',
                  color: dayColor,
                ),
                const SizedBox(width: 12),
                _Badge(
                  label: 'Totale',
                  value: '${summary.totalPnl >= 0 ? '+' : ''}${_fmt.format(summary.totalPnl)} (${_pct.format(summary.totalPnlPct)}%)',
                  color: pnlColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${summary.holdingCount} posizioni · Investito ${_fmt.format(summary.totalCost)}',
                style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Badge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyPortfolio extends StatelessWidget {
  const _EmptyPortfolio();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.add_chart, color: kMuted, size: 48),
            const SizedBox(height: 12),
            const Text('Nessuna posizione', style: TextStyle(color: kMuted)),
            const SizedBox(height: 8),
            const Text('Aggiungi una transazione per iniziare a tracciare il portafoglio.',
                style: TextStyle(color: kMuted, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SummaryShimmer extends StatelessWidget {
  const _SummaryShimmer();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 12, width: 120, color: kBorder),
            const SizedBox(height: 8),
            Container(height: 36, width: 200, color: kBorder),
            const SizedBox(height: 16),
            Container(height: 12, width: 180, color: kBorder),
          ],
        ),
      ),
    );
  }
}

class _TileShimmer extends StatelessWidget {
  const _TileShimmer();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(height: 40, width: 40, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 80, color: kBorder),
                const SizedBox(height: 6),
                Container(height: 10, width: 60, color: kBorder),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Errore: $error', style: const TextStyle(color: kRed, fontSize: 13)),
      ),
    );
  }
}
