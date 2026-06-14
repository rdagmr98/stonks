class AppUser {
  final String id;
  final String email;
  final String username;
  final String currency;

  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    required this.currency,
  });

  factory AppUser.fromProfile(Map<String, dynamic> profile, String email) => AppUser(
        id: profile['id'] as String,
        email: email,
        username: profile['username'] as String,
        currency: profile['currency'] as String? ?? 'EUR',
      );
}
