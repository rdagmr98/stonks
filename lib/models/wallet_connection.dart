class WalletConnection {
  final String id;
  final String type; // 'exchange' | 'address'
  final String name; // label utente
  // exchange
  final String? exchange; // 'coinbase' | 'binance' | 'kraken'
  final String? apiKey;
  final String? apiSecret; // encrypted
  // address
  final String? chain;   // 'bitcoin' | 'ethereum' | 'solana' | 'ton' | ...
  final String? address;

  const WalletConnection({
    required this.id,
    required this.type,
    required this.name,
    this.exchange,
    this.apiKey,
    this.apiSecret,
    this.chain,
    this.address,
  });

  factory WalletConnection.fromJson(Map<String, dynamic> j) => WalletConnection(
        id: j['id'] as String,
        type: j['type'] as String,
        name: j['name'] as String,
        exchange: j['exchange'] as String?,
        apiKey: j['api_key'] as String?,
        apiSecret: j['api_secret'] as String?,
        chain: j['chain'] as String?,
        address: j['address'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (exchange != null) 'exchange': exchange,
        if (apiKey != null) 'api_key': apiKey,
        if (apiSecret != null) 'api_secret': apiSecret,
        if (chain != null) 'chain': chain,
        if (address != null) 'address': address,
      };
}
