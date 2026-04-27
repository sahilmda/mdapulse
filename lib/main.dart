import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/authentication/presentation/screens/login_screen.dart';
import 'package:mda_crm/features/client_management/presentation/screens/customer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = (prefs.getString('CLIENTID') ?? '').isNotEmpty;
  runApp(MDACrmApp(isLoggedIn: isLoggedIn));
}

class MDACrmApp extends StatelessWidget {
  final bool isLoggedIn;
  const MDACrmApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDA CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0257E6)),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const CustomerScreen() : const LoginScreen(),
    );
  }
}
