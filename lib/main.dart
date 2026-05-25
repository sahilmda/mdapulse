import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/authentication/presentation/screens/login_screen.dart';
import 'package:mda_crm/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:mda_crm/shared/theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = (prefs.getString('CLIENTID') ?? '').isNotEmpty;
  await themeNotifier.loadTheme();
  runApp(MDACrmApp(isLoggedIn: isLoggedIn));
}

class MDACrmApp extends StatelessWidget {
  final bool isLoggedIn;
  const MDACrmApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeState>(
      valueListenable: themeNotifier,
      builder: (_, themeState, _) => MaterialApp(
        title: 'MDA Pulse',
        debugShowCheckedModeBanner: false,
        themeMode: themeState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0257E6)),
          appBarTheme: AppBarTheme(
            backgroundColor: themeState.topBarColor,
            foregroundColor: themeState.topBarColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            iconTheme: IconThemeData(color: themeState.topBarColor.computeLuminance() > 0.5 ? Colors.black : Colors.white),
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0257E6), brightness: Brightness.dark),
          appBarTheme: AppBarTheme(
            backgroundColor: themeState.topBarColor == Colors.white ? const Color(0xFF1E1E1E) : themeState.topBarColor,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          useMaterial3: true,
        ),
        builder: (context, child) {
          // Cap text scale to 1.3× so layouts never break at large accessibility sizes
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                maxScaleFactor: 1.3,
              ),
            ),
            child: child!,
          );
        },
        home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }
}
