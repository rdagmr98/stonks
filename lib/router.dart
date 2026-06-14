import 'package:go_router/go_router.dart';
import 'models/holding.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/portfolio/portfolio_screen.dart';
import 'screens/portfolio/holding_detail_screen.dart';
import 'screens/transactions/transactions_screen.dart';
import 'screens/transactions/add_transaction_screen.dart';
import 'screens/transactions/import_csv_screen.dart';
import 'screens/dividends/dividends_screen.dart';
import 'screens/watchlist/watchlist_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/wallets/wallet_connections_screen.dart';
import 'screens/shell_screen.dart';
import 'services/auth_service.dart';
import 'services/gh_db_service.dart';

final router = GoRouter(
  initialLocation: '/setup',
  redirect: (context, state) {
    final hasToken = GhDbService().hasToken;
    final loggedIn = AuthService().isLoggedIn;
    final loc = state.matchedLocation;

    if (!hasToken) return loc == '/setup' ? null : '/setup';
    if (!loggedIn) return (loc == '/login' || loc == '/setup') ? null : '/login';
    if (loc == '/login' || loc == '/setup') return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/setup', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/add-transaction', builder: (_, __) => const AddTransactionScreen()),
    GoRoute(path: '/import-csv', builder: (_, __) => const ImportCsvScreen()),
    GoRoute(
      path: '/holding',
      builder: (_, state) => HoldingDetailScreen(holding: state.extra as Holding),
    ),
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/portfolio', builder: (_, __) => const PortfolioScreen()),
        GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
        GoRoute(path: '/dividends', builder: (_, __) => const DividendsScreen()),
        GoRoute(path: '/watchlist', builder: (_, __) => const WatchlistScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/wallets', builder: (_, __) => const WalletConnectionsScreen()),
      ],
    ),
  ],
);
