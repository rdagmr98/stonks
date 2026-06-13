class Holding {
  final String id;
  final String symbol;
  final String name;
  final String type; // stock, etf, crypto
  final String currency;
  final double shares;
  final double avgCost;
  final String notes;

  const Holding({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.currency,
    required this.shares,
    required this.avgCost,
    this.notes = '',
  });

  double get totalCost => shares * avgCost;

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        currency: j['currency'] as String,
        shares: (j['shares'] as num).toDouble(),
        avgCost: (j['avg_cost'] as num).toDouble(),
        notes: j['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'type': type,
        'currency': currency,
        'shares': shares,
        'avg_cost': avgCost,
        'notes': notes,
      };

  Holding copyWith({
    String? id,
    String? symbol,
    String? name,
    String? type,
    String? currency,
    double? shares,
    double? avgCost,
    String? notes,
  }) =>
      Holding(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        shares: shares ?? this.shares,
        avgCost: avgCost ?? this.avgCost,
        notes: notes ?? this.notes,
      );
}
