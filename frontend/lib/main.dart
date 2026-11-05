import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'src/core/theme/rr_theme.dart';
import 'src/core/theme/theme_provider.dart';
import 'src/features/auth/presentation/providers/auth_provider.dart';
import 'src/features/auth/presentation/screens/welcome_screen.dart';
import 'src/features/home/presentation/screens/main_navigation_screen.dart';
import 'src/features/workouts/presentation/workouts_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutsProvider()),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'RunnersRun',
          debugShowCheckedModeBanner: false,
          theme: buildRRTheme(Brightness.light),
          darkTheme: buildRRTheme(Brightness.dark),
          themeMode: context.watch<ThemeProvider>().mode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

/// Decide dinamicamente se o usuário vai direto para a Comunidade ou para as Boas-vindas
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isAuthenticated) {
      return const MainNavigationScreen();
    }

    if (authProvider.isLoading) {
      return Scaffold(
        backgroundColor: context.rr.canvas,
        body: const Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }

    return const WelcomeScreen();
  }
}
