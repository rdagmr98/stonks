class StTransaction {
  final String id;
  final String symbol;
  final String name;
  final String type; // buy, sell, dividend
  final DateTime date;
  final double shares;
  final double price;
  final double fees;
  final String currency;
  final String notes;

  const StTransaction({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.date,
    required this.shares,
    required this.price,
    required this.fees,
    required this.currency,
    this.notes = '',
  });

  double get total => shares * price + fees;
  double get net => type == 'sell' ? shares * price - fees : total;

  factory StTransaction.fromJson(Map<String, dynamic> j) => StTransaction(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        name: j['name'] as String? ?? j['symbol'] as String,
        type: j['type'] as String,
        date: DateTime.parse(j['date'] as String),
        shares: (j['shares'] as num).toDouble(),
        price: (j['price'] as num).toDouble(),
        fees: (j['fees'] as num? ?? 0).toDouble(),
        currency: j['currency'] as String? ?? 'EUR',
        notes: j['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'type': type,
        'date': date.toIso8601String().substring(0, 10),
        'shares': shares,
        'price': price,
        'fees': fees,
        'currency': currency,
        'notes': notes,
      };
}
