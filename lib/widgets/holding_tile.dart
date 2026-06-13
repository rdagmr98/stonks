import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/holding.dart';
import '../models/quote.dart';
import '../theme/app_theme.dart';

final _moneyFmt = NumberFormat.currency(locale: 'it_IT', symbol: '€', decimalDigits: 2);
final _pct = NumberFormat('+#,##0.00;-#,##0.00', 'it_IT');

class HoldingTile extends StatelessWidget {
  final Holding holding;
  final Quote? quote;

  const HoldingTile({super.key, required this.holding, this.quote});

  @override
  Widget build(BuildContext context) {
    final price = quote?.price ?? holding.avgCost;
    final value = holding.shares * price;
    final pnl = value - holding.totalCost;
    final pnlPct = holding.totalCost > 0 ? pnl / holding.totalCost * 100 : 0.0;
    final pnlColor = pnl >= 0 ? kGreen : kRed;
    final dayChange = quote?.changePercent ?? 0;
    final dayColor = dayChange >= 0 ? kGreen : kRed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _SymbolBadge(symbol: holding.symbol, type: holding.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(holding.symbol,
                      style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(holding.name, style: const TextStyle(color: kMuted, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${holding.shares.toStringAsFixed(holding.shares % 1 == 0 ? 0 : 4)} pz · pm ${_moneyFmt.format(holding.avgCost)}',
                      style: const TextStyle(color: kMuted, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_moneyFmt.format(value),
                    style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${pnl >= 0 ? '+' : ''}${_moneyFmt.format(pnl)} (${_pct.format(pnlPct)}%)',
                    style: TextStyle(color: pnlColor, fontSize: 12)),
                if (quote != null)
                  Text('oggi ${_pct.format(dayChange)}%',
                      style: TextStyle(color: dayColor, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SymbolBadge extends StatelessWidget {
  final String symbol;
  final String type;
  const _SymbolBadge({required this.symbol, required this.type});

  Color get _color {
    switch (type) {
      case 'etf': return kYellow;
      case 'crypto': return const Color(0xFFF7931A);
      default: return kBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = symbol.length > 4 ? symbol.substring(0, 4) : symbol;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
