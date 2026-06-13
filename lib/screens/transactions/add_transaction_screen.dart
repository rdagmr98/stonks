import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/providers.dart';
import '../../services/portfolio_service.dart';
import '../../theme/app_theme.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symbol = TextEditingController();
  final _name = TextEditingController();
  final _shares = TextEditingController();
  final _price = TextEditingController();
  final _fees = TextEditingController(text: '0');
  final _notes = TextEditingController();

  String _type = 'buy';
  DateTime _date = DateTime.now();
  String _currency = 'EUR';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_symbol, _name, _shares, _price, _fees, _notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final tx = StTransaction(
        id: PortfolioService.newId(),
        symbol: _symbol.text.trim().toUpperCase(),
        name: _name.text.trim().isEmpty ? _symbol.text.trim().toUpperCase() : _name.text.trim(),
        type: _type,
        date: _date,
        shares: double.parse(_shares.text.replaceAll(',', '.')),
        price: double.parse(_price.text.replaceAll(',', '.')),
        fees: double.tryParse(_fees.text.replaceAll(',', '.')) ?? 0,
        currency: _currency,
        notes: _notes.text,
      );
      await PortfolioService().addTransaction(tx);
      ref.invalidate(transactionsProvider);
      ref.invalidate(holdingsProvider);
      ref.invalidate(portfolioSummaryProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: kRed));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova transazione')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selector
            Row(
              children: ['buy', 'sell', 'dividend'].map((t) {
                final selected = _type == t;
                final color = t == 'buy' ? kGreen : t == 'sell' ? kRed : kYellow;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _type = t),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
                        side: BorderSide(color: selected ? color : kBorder),
                        foregroundColor: selected ? color : kMuted,
                      ),
                      child: Text(t.toUpperCase()),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _symbol,
                    decoration: const InputDecoration(labelText: 'Simbolo *', hintText: 'AAPL'),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v == null || v.isEmpty ? 'Obbligatorio' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nome', hintText: 'Apple Inc.'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shares,
                    decoration: const InputDecoration(labelText: 'Quantità *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obbligatorio';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Numero non valido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Prezzo *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obbligatorio';
                      if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Numero non valido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fees,
                    decoration: const InputDecoration(labelText: 'Commissioni'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    dropdownColor: kCard,
                    decoration: const InputDecoration(labelText: 'Valuta'),
                    items: ['EUR', 'USD', 'GBP', 'CHF']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Date picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: kPrimary, surface: kCard),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data', suffixIcon: Icon(Icons.calendar_today, size: 18, color: kMuted)),
                child: Text(DateFormat('dd/MM/yyyy').format(_date), style: const TextStyle(color: kText)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Salva transazione'),
            ),
          ],
        ),
      ),
    );
  }
}
