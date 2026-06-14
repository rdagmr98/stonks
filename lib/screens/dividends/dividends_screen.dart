import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

final _moneyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);
final _moneyCompact = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 0);

class DividendsScreen extends ConsumerStatefulWidget {
  const DividendsScreen({super.key});

  @override
  ConsumerState<DividendsScreen> createState() => _DividendsScreenState();
}

class _DividendsScreenState extends ConsumerState<DividendsScreen> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dividendi')),
      body: txAsync.when(
        data: (txs) {
          final dividends = txs.where((t) => t.type == 'dividend').toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (dividends.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payments_outlined, color: kMuted, size: 56),
                  SizedBox(height: 12),
                  Text('Nessun dividendo', style: TextStyle(color: kMuted)),
                  SizedBox(height: 4),
                  Text('Aggiungi transazioni di tipo "dividendo".',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            );
          }

          final years = dividends.map((d) => d.date.year).toSet().toList()
            ..sort((a, b) => b.compareTo(a));
          _selectedYear ??= years.first;

          final byYear = <int, List<StTransaction>>{};
          for (final d in dividends) {
            byYear.putIfAbsent(d.date.year, () => []).add(d);
          }

          final yearDivs = byYear[_selectedYear!] ?? [];
          final monthlyTotals = _monthlyTotals(yearDivs);
          final yearTotal = yearDivs.fold<double>(0, (s, d) => s + d.total);
          final allTimeTotal = dividends.fold<double>(0, (s, d) => s + d.total);

          // Group by symbol for the selected year
          final bySymbol = <String, double>{};
          for (final d in yearDivs) {
            bySymbol[d.symbol] = (bySymbol[d.symbol] ?? 0) + d.total;
          }
          final symbolList = bySymbol.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(transactionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // All-time total card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.payments, color: kYellow, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dividendi totali', style: TextStyle(color: kMuted, fontSize: 12)),
                            Text(_moneyFmt.format(allTimeTotal),
                                style: const TextStyle(color: kYellow, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Year selector
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: years.map((y) {
                      final sel = y == _selectedYear;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$y'),
                          selected: sel,
                          onSelected: (_) => setState(() => _selectedYear = y),
                          backgroundColor: kSurface,
                          selectedColor: kYellow.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: sel ? kYellow : kMuted,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                          ),
                          side: BorderSide(color: sel ? kYellow : kBorder),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Year total + bar chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$_selectedYear', style: const TextStyle(color: kMuted, fontSize: 13)),
                            Text(_moneyFmt.format(yearTotal),
                                style: const TextStyle(color: kYellow, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: _MonthlyBarChart(monthlyTotals: monthlyTotals),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Per-symbol breakdown
                if (symbolList.isNotEmpty) ...[
                  const Text('Per simbolo', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...symbolList.map((e) => _SymbolRow(symbol: e.key, amount: e.value, yearTotal: yearTotal)),
                  const SizedBox(height: 12),
                ],

                // Transaction list for selected year
                const Text('Dettaglio', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...yearDivs.map((d) => _DivTile(tx: d)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: kRed))),
      ),
    );
  }

  List<double> _monthlyTotals(List<StTransaction> divs) {
    final months = List<double>.filled(12, 0);
    for (final d in divs) {
      months[d.date.month - 1] += d.total;
    }
    return months;
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<double> monthlyTotals;
  const _MonthlyBarChart({required this.monthlyTotals});

  static const _months = ['G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxY = monthlyTotals.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) {
      return const Center(child: Text('Nessun dato mensile', style: TextStyle(color: kMuted, fontSize: 12)));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => kCard,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '€${rod.toY.toStringAsFixed(0)}',
              const TextStyle(color: kYellow, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Text(
                _months[v.toInt()],
                style: const TextStyle(color: kMuted, fontSize: 10),
              ),
            ),
          ),
        ),
        barGroups: List.generate(12, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthlyTotals[i],
              color: monthlyTotals[i] > 0 ? kYellow : kBorder,
              width: 14,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        )),
      ),
    );
  }
}

class _SymbolRow extends StatelessWidget {
  final String symbol;
  final double amount;
  final double yearTotal;
  const _SymbolRow({required this.symbol, required this.amount, required this.yearTotal});

  @override
  Widget build(BuildContext context) {
    final pct = yearTotal > 0 ? amount / yearTotal : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: kYellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              symbol.length > 4 ? symbol.substring(0, 4) : symbol,
              style: const TextStyle(color: kYellow, fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(symbol, style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_moneyFmt.format(amount), style: const TextStyle(color: kYellow, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: kBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(kYellow),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: kMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DivTile extends StatelessWidget {
  final StTransaction tx;
  const _DivTile({required this.tx});

  static final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kYellow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.payments_outlined, color: kYellow, size: 18),
        ),
        title: Text(tx.symbol, style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(_fmt.format(tx.date), style: const TextStyle(color: kMuted, fontSize: 11)),
        trailing: Text(_moneyFmt.format(tx.total),
            style: const TextStyle(color: kYellow, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
