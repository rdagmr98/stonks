class Quote {
  final String symbol;
  final double price;
  final double change;
  final double changePercent;
  final String currency;
  final DateTime fetchedAt;

  const Quote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.currency,
    required this.fetchedAt,
  });
}
