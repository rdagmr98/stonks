class WatchlistItem {
  final String id;
  final String symbol;
  final String name;
  final String type;
  final double? targetPrice;
  final String notes;

  const WatchlistItem({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    this.targetPrice,
    this.notes = '',
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> j) => WatchlistItem(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        targetPrice: j['target_price'] != null ? (j['target_price'] as num).toDouble() : null,
        notes: j['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'type': type,
        'target_price': targetPrice,
        'notes': notes,
      };
}
