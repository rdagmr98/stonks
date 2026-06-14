import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';
import '../../services/portfolio_service.dart';
import '../../theme/app_theme.dart';

// CSV format expected (header row optional):
// data,simbolo,nome,tipo,quantita,prezzo,valuta,commissioni
// 2024-01-15,AAPL,Apple Inc,buy,10,185.50,USD,1.50

class ImportCsvScreen extends ConsumerStatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  ConsumerState<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends ConsumerState<ImportCsvScreen> {
  final _ctrl = TextEditingController();
  List<_ParsedRow>? _preview;
  String? _error;
  bool _importing = false;

  static const _dateFormats = ['yyyy-MM-dd', 'dd/MM/yyyy', 'dd-MM-yyyy', 'MM/dd/yyyy'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _error = null;
      _preview = null;
    });

    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Incolla il CSV nel campo sopra.');
      return;
    }

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) {
      setState(() => _error = 'Nessuna riga trovata.');
      return;
    }

    // Skip header if first row looks like text
    int start = 0;
    final firstCols = lines[0].split(',');
    if (firstCols.isNotEmpty && double.tryParse(firstCols[0].trim()) == null &&
        _parseDate(firstCols[0].trim()) == null) {
      start = 1;
    }

    final rows = <_ParsedRow>[];
    final errors = <String>[];

    for (var i = start; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length < 6) {
        errors.add('Riga ${i + 1}: colonne insufficienti (${cols.length}/6 min)');
        continue;
      }

      final dateStr = cols[0].trim();
      final symbol = cols[1].trim().toUpperCase();
      final name = cols[2].trim();
      final type = cols[3].trim().toLowerCase();
      final shares = double.tryParse(cols[4].trim());
      final price = double.tryParse(cols[5].trim());
      final currency = cols.length > 6 ? cols[6].trim().toUpperCase() : 'EUR';
      final fees = cols.length > 7 ? (double.tryParse(cols[7].trim()) ?? 0.0) : 0.0;

      final date = _parseDate(dateStr);
      if (date == null) {
        errors.add('Riga ${i + 1}: data non valida "$dateStr"');
        continue;
      }
      if (symbol.isEmpty) {
        errors.add('Riga ${i + 1}: simbolo vuoto');
        continue;
      }
      if (!['buy', 'sell', 'dividend', 'acquisto', 'vendita', 'dividendo'].contains(type)) {
        errors.add('Riga ${i + 1}: tipo non valido "$type" (usa buy/sell/dividend)');
        continue;
      }
      if (shares == null || shares <= 0) {
        errors.add('Riga ${i + 1}: quantità non valida');
        continue;
      }
      if (price == null || price < 0) {
        errors.add('Riga ${i + 1}: prezzo non valido');
        continue;
      }

      // Normalize type
      final normType = type == 'acquisto' ? 'buy' : type == 'vendita' ? 'sell' : type == 'dividendo' ? 'dividend' : type;

      rows.add(_ParsedRow(
        date: date,
        symbol: symbol,
        name: name.isEmpty ? symbol : name,
        type: normType,
        shares: shares,
        price: price,
        currency: currency,
        fees: fees,
      ));
    }

    if (rows.isEmpty && errors.isNotEmpty) {
      setState(() => _error = errors.join('\n'));
      return;
    }

    setState(() {
      _preview = rows;
      if (errors.isNotEmpty) {
        _error = 'Righe con errori (saltate):\n${errors.join('\n')}';
      }
    });
  }

  DateTime? _parseDate(String s) {
    for (final fmt in _dateFormats) {
      try {
        return DateFormat(fmt).parseStrict(s);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _import() async {
    if (_preview == null || _preview!.isEmpty) return;
    setState(() => _importing = true);

    try {
      final uuid = const Uuid();
      final svc = PortfolioService();
      for (final row in _preview!) {
        final tx = StTransaction(
          id: uuid.v4(),
          symbol: row.symbol,
          name: row.name,
          type: row.type,
          shares: row.shares,
          price: row.price,
          currency: row.currency,
          fees: row.fees,
          date: row.date,
        );
        await svc.addTransaction(tx);
      }
      ref.invalidate(transactionsProvider);
      ref.invalidate(holdingsProvider);
      ref.invalidate(portfolioSummaryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importate ${_preview!.length} transazioni'),
            backgroundColor: kGreen,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Errore durante import: $e';
        _importing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importa CSV')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Format hint
          Card(
            color: kBlue.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Formato CSV', style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text(
                    'data,simbolo,nome,tipo,quantita,prezzo,valuta,commissioni\n'
                    '2024-01-15,AAPL,Apple Inc,buy,10,185.50,USD,1.50\n'
                    '2024-03-20,VOO,Vanguard S&P 500,dividend,0,1.25,USD,0',
                    style: TextStyle(color: kMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tipi: buy · sell · dividend (o acquisto/vendita/dividendo)\n'
                    'Date: yyyy-MM-dd · dd/MM/yyyy · dd-MM-yyyy\n'
                    'Valuta: EUR · USD · GBP · CHF (default EUR)\n'
                    'Colonne valuta e commissioni opzionali',
                    style: TextStyle(color: kMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // CSV input
          TextField(
            controller: _ctrl,
            maxLines: 8,
            style: const TextStyle(color: kText, fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'Incolla qui il contenuto CSV...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.search),
            label: const Text('Analizza'),
            style: ElevatedButton.styleFrom(backgroundColor: kSurface, foregroundColor: kBlue),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
            ),
          ],

          if (_preview != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Anteprima — ${_preview!.length} transazioni',
                    style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload),
                  label: Text(_importing ? 'Importando...' : 'Importa tutto'),
                  style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._preview!.map((r) => _PreviewTile(row: r)),
          ],
        ],
      ),
    );
  }
}

class _ParsedRow {
  final DateTime date;
  final String symbol;
  final String name;
  final String type;
  final double shares;
  final double price;
  final String currency;
  final double fees;

  const _ParsedRow({
    required this.date,
    required this.symbol,
    required this.name,
    required this.type,
    required this.shares,
    required this.price,
    required this.currency,
    required this.fees,
  });
}

class _PreviewTile extends StatelessWidget {
  final _ParsedRow row;
  const _PreviewTile({required this.row});

  Color get _color => row.type == 'buy' ? kGreen : row.type == 'sell' ? kRed : kYellow;
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            Text(_dateFmt.format(row.date), style: const TextStyle(color: kMuted, fontSize: 11)),
            const SizedBox(width: 8),
            Text(row.symbol, style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text(row.type.toUpperCase(), style: TextStyle(color: _color, fontSize: 10)),
            const Spacer(),
            Text('${row.shares} @ ${row.price.toStringAsFixed(2)} ${row.currency}',
                style: const TextStyle(color: kText, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
