class AppUser {
  final String id;
  final String username;
  final String passwordHash;
  final String name;
  final String currency;
  final String role; // admin, viewer

  const AppUser({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.name,
    required this.currency,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        username: j['username'] as String,
        passwordHash: j['password_hash'] as String,
        name: j['name'] as String,
        currency: j['currency'] as String? ?? 'EUR',
        role: j['role'] as String? ?? 'viewer',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'password_hash': passwordHash,
        'name': name,
        'currency': currency,
        'role': role,
      };
}
