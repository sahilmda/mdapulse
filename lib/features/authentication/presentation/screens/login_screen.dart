import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mda_crm/features/dashboard/presentation/screens/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _clientIdController.dispose();
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_clientIdController.text.trim().isEmpty ||
        _userIdController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Default.aspx/Login'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          "ClientId": _clientIdController.text.trim(),
          "UserName": _userIdController.text.trim(),
          "Password": _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final String rawData = jsonDecode(response.body)['d'] ?? '';

        if (rawData.contains('^')) {
          final parts = rawData.split('^');
          if (parts.length >= 24) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('CLIENTID', parts[0]);
            await prefs.setString('sno', parts[1]);
            await prefs.setString('UName', parts[2]);
            await prefs.setString('U_SNo', parts[3]);
            await prefs.setString('UCode', parts[4]);
            await prefs.setString('O_Name', parts[5]);
            await prefs.setString('D_Database', parts[6]);
            await prefs.setString('AutoAllot', parts[7]);
            await prefs.setString('WAPP', parts[8]);
            await prefs.setString('Architect', parts[9]);
            await prefs.setString('Arch_Name', parts[10]);
            await prefs.setString('Grade', parts[11]);
            await prefs.setString('LogoURL', parts[12]);
            await prefs.setString('showAllCustomer', parts[13]);
            await prefs.setString('BaseCity', parts[14]);
            await prefs.setString('Hide_Activity', parts[15]);
            await prefs.setString('Hide_Executive', parts[16]);
            await prefs.setString('Hide_FDATE', parts[17]);
            await prefs.setString('Hide_OldCust', parts[18]);
            await prefs.setString('Quotation', parts[19]);
            await prefs.setString('Quote_History', parts[20]);
            await prefs.setString('Enable_PrePostSale', parts[21]);
            await prefs.setString('EnableProd_Rep', parts[22]);
            await prefs.setString('EnableAct_Rep', parts[23]);

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          } else {
            setState(() => _errorMessage = 'Incomplete data received from server.');
          }
        } else {
          setState(() => _errorMessage = rawData.isNotEmpty ? rawData : 'Invalid credentials. Please try again.');
        }
      } else {
        setState(() => _errorMessage = 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to connect to the server. Check your internet connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF221A41), Color(0xFF38153B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5D54C4).withValues(alpha: 0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/mda_pulse_logo.png',
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'MDA Pulse',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF2C97D4)),
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildTextField(hint: 'Client ID', controller: _clientIdController),
                    const SizedBox(height: 16),
                    _buildTextField(hint: 'User ID / Email ID', controller: _userIdController),
                    const SizedBox(height: 16),
                    _buildTextField(hint: 'Password', controller: _passwordController, isPassword: true),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6B62D4), Color(0xFF4945D1)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String hint, required TextEditingController controller, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey.shade400, size: 20),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6B62D4), width: 1.5)),
      ),
    );
  }
}
