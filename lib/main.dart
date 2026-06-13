import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/gh_db_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GhDbService().init();
  await AuthService().tryAutoLogin();
  runApp(const ProviderScope(child: StonksApp()));
}

class StonksApp extends StatelessWidget {
  const StonksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stonks',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: router,
    );
  }
}
