import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/holding.dart';
import '../models/quote.dart';
import '../theme/app_theme.dart';

class AllocationChart extends StatefulWidget {
  final List<Holding> holdings;
  final Map<String, Quote?> quotes;
  const AllocationChart({super.key, required this.holdings, required this.quotes});

  @override
  State<AllocationChart> createState() => _AllocationChartState();
}

class _AllocationChartState extends State<AllocationChart> {
  int _touchedIndex = -1;

  static const _colors = [kBlue, kGreen, kYellow, kRed, Color(0xFF6E76F7), Color(0xFFF7931A), kMuted];

  @override
  Widget build(BuildContext context) {
    final data = <String, double>{};
    for (final h in widget.holdings) {
      final price = widget.quotes[h.symbol]?.price ?? h.avgCost;
      data[h.symbol] = (data[h.symbol] ?? 0) + h.shares * price;
    }
    final total = data.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox();

    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Allocazione', style: TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, resp) {
                            setState(() {
                              _touchedIndex = resp?.touchedSection?.touchedSectionIndex ?? -1;
                            });
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: entries.asMap().entries.map((e) {
                          final idx = e.key;
                          final touched = idx == _touchedIndex;
                          final pct = e.value.value / total * 100;
                          return PieChartSectionData(
                            color: _colors[idx % _colors.length],
                            value: e.value.value,
                            title: touched ? '${pct.toStringAsFixed(1)}%' : '',
                            radius: touched ? 60 : 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kText),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.asMap().entries.take(6).map((e) {
                      final idx = e.key;
                      final pct = e.value.value / total * 100;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                    color: _colors[idx % _colors.length],
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 6),
                            Text(e.value.key, style: const TextStyle(color: kText, fontSize: 12)),
                            const SizedBox(width: 4),
                            Text('${pct.toStringAsFixed(1)}%',
                                style: const TextStyle(color: kMuted, fontSize: 11)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
