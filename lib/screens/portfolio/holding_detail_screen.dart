import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/holding.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';
import '../../services/market_service.dart';
import '../../theme/app_theme.dart';

final _moneyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);
final _dateFmt = DateFormat('dd/MM/yyyy');
final _pct = NumberFormat('+#,##0.00;-#,##0.00', 'it_IT');

class HoldingDetailScreen extends ConsumerStatefulWidget {
  final Holding holding;
  const HoldingDetailScreen({super.key, required this.holding});

  @override
  ConsumerState<HoldingDetailScreen> createState() => _HoldingDetailScreenState();
}

class _HoldingDetailScreenState extends ConsumerState<HoldingDetailScreen> {
  String _range = '1mo';

  static const _ranges = [
    ('1d', '1G'),
    ('1wk', '1S'),
    ('1mo', '1M'),
    ('3mo', '3M'),
    ('1y', '1A'),
    ('5y', '5A'),
  ];

  @override
  Widget build(BuildContext context) {
    final h = widget.holding;
    final quoteAsync = ref.watch(quotesProvider(h.symbol));
    final historyAsync = ref.watch(priceHistoryProvider((h.symbol, _range)));
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(h.symbol),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-transaction'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          // Price header
          quoteAsync.when(
            data: (q) => _PriceHeader(holding: h, quote: q),
            loading: () => const _HeaderShimmer(),
            error: (_, __) => _PriceHeader(holding: h, quote: null),
          ),
          // Chart
          _ChartSection(
            historyAsync: historyAsync,
            range: _range,
            ranges: _ranges,
            onRangeChanged: (r) => setState(() => _range = r),
            holding: h,
          ),
          const SizedBox(height: 8),
          // Position details
          quoteAsync.when(
            data: (q) => _PositionCard(holding: h, quote: q),
            loading: () => const SizedBox(),
            error: (_, __) => _PositionCard(holding: h, quote: null),
          ),
          const SizedBox(height: 8),
          // Transactions for this symbol
          txAsync.when(
            data: (txs) {
              final filtered = txs.where((t) => t.symbol == h.symbol).toList();
              return _TransactionSection(transactions: filtered);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  final Holding holding;
  final dynamic quote;
  const _PriceHeader({required this.holding, required this.quote});

  @override
  Widget build(BuildContext context) {
    final price = quote?.price ?? holding.avgCost;
    final change = quote?.change ?? 0.0;
    final changePct = quote?.changePercent ?? 0.0;
    final currency = quote?.currency ?? holding.currency;
    final color = change >= 0 ? kGreen : kRed;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(holding.name, style: const TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat.currency(symbol: currency == 'EUR' ? '€' : currency == 'USD' ? '\$' : '$currency ', decimalDigits: 2).format(price),
                style: const TextStyle(color: kText, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(change >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: color, size: 20),
              Text(
                '${change >= 0 ? '+' : ''}${price != 0 ? change.toStringAsFixed(2) : '0.00'} (${_pct.format(changePct)}%)',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              const Text('oggi', style: TextStyle(color: kMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderShimmer extends StatelessWidget {
  const _HeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 12, width: 100, color: kBorder),
          const SizedBox(height: 8),
          Container(height: 36, width: 160, color: kBorder),
          const SizedBox(height: 8),
          Container(height: 12, width: 120, color: kBorder),
        ],
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  final AsyncValue<List<PricePoint>> historyAsync;
  final String range;
  final List<(String, String)> ranges;
  final ValueChanged<String> onRangeChanged;
  final Holding holding;

  const _ChartSection({
    required this.historyAsync,
    required this.range,
    required this.ranges,
    required this.onRangeChanged,
    required this.holding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Range selector
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ranges.map((r) {
              final (value, label) = r;
              final selected = range == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => onRangeChanged(value),
                  backgroundColor: kSurface,
                  selectedColor: kBlue.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: selected ? kBlue : kMuted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                  side: BorderSide(color: selected ? kBlue : kBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Chart
        SizedBox(
          height: 200,
          child: historyAsync.when(
            data: (points) => points.isEmpty
                ? const Center(child: Text('Nessun dato storico', style: TextStyle(color: kMuted)))
                : _PriceChart(points: points, holding: holding),
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Center(child: Text('Errore caricamento dati', style: TextStyle(color: kMuted))),
          ),
        ),
      ],
    );
  }
}

class _PriceChart extends StatelessWidget {
  final List<PricePoint> points;
  final Holding holding;
  const _PriceChart({required this.points, required this.holding});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    final spots = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();
    final first = points.first.close;
    final last = points.last.close;
    final isUp = last >= first;
    final lineColor = isUp ? kGreen : kRed;
    final minY = points.map((p) => p.close).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.close).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return Padding(
      padding: const EdgeInsets.only(right: 16, left: 8),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          minY: minY - padding,
          maxY: maxY + padding,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => kCard,
              getTooltipItems: (spots) => spots.map((s) {
                final pt = points[s.x.toInt()];
                return LineTooltipItem(
                  '${s.y.toStringAsFixed(2)}\n',
                  TextStyle(color: lineColor, fontSize: 12, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: DateFormat('dd/MM').format(pt.date),
                      style: const TextStyle(color: kMuted, fontSize: 10),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: lineColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [lineColor.withValues(alpha: 0.2), lineColor.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
          // Linea prezzo medio di carico
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: holding.avgCost,
                color: kYellow.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(color: kYellow, fontSize: 10),
                  labelResolver: (_) => 'pm ${holding.avgCost.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final Holding holding;
  final dynamic quote;
  const _PositionCard({required this.holding, required this.quote});

  @override
  Widget build(BuildContext context) {
    final price = quote?.price ?? holding.avgCost;
    final value = holding.shares * price;
    final pnl = value - holding.totalCost;
    final pnlPct = holding.totalCost > 0 ? pnl / holding.totalCost * 100 : 0.0;
    final pnlColor = pnl >= 0 ? kGreen : kRed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('La tua posizione',
                  style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _Row('Quantità', '${holding.shares.toStringAsFixed(holding.shares % 1 == 0 ? 0 : 4)} pz'),
              const SizedBox(height: 8),
              _Row('Prezzo medio', _moneyFmt.format(holding.avgCost)),
              const SizedBox(height: 8),
              _Row('Investito', _moneyFmt.format(holding.totalCost)),
              const Divider(color: kBorder, height: 20),
              _Row('Valore attuale', _moneyFmt.format(value), valueColor: kText),
              const SizedBox(height: 8),
              _Row(
                'Guadagno/Perdita',
                '${pnl >= 0 ? '+' : ''}${_moneyFmt.format(pnl)} (${_pct.format(pnlPct)}%)',
                valueColor: pnlColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? kText, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TransactionSection extends StatelessWidget {
  final List<StTransaction> transactions;
  const _TransactionSection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Transazioni',
              style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...transactions.map((tx) => _TxRow(tx: tx)),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final StTransaction tx;
  const _TxRow({required this.tx});

  Color get _color => tx.type == 'buy' ? kGreen : tx.type == 'sell' ? kRed : kYellow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          Text(_dateFmt.format(tx.date), style: const TextStyle(color: kMuted, fontSize: 12)),
          const SizedBox(width: 8),
          Text(tx.type.toUpperCase(),
              style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${tx.shares} @ ${tx.price.toStringAsFixed(2)}',
              style: const TextStyle(color: kText, fontSize: 12)),
          const SizedBox(width: 8),
          Text(_moneyFmt.format(tx.total),
              style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
