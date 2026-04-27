// File: lib/features/auth/presentation/screens/login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Note: Adjust this import path if your customer screen is elsewhere!
import 'package:mda_crm/features/client_management/presentation/screens/customer_screen.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);
const Color mdaAccentPurple = Color(0xFF6366F1);
const Color mdaInputBg = Color(0xFFE8F0FE); 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false; // Added back!
  String? _errorMessage;           // Added back!

  void _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (_clientIdController.text.trim().isEmpty || 
        _usernameController.text.trim().isEmpty || 
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://mdapulse.com/Default.aspx/Login'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          "ClientId": _clientIdController.text.trim(),
          "UserName": _usernameController.text.trim(),
          "Password": _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String rawData = responseData['d'] ?? '';

        if (rawData.contains('^')) {
          final List<String> dataParts = rawData.split('^');
          
          if (dataParts.length >= 24) {
            final prefs = await SharedPreferences.getInstance();
            
            await prefs.setString("CLIENTID", dataParts[0]);
            await prefs.setString("sno", dataParts[1]);
            await prefs.setString("UName", dataParts[2]);
            await prefs.setString("U_SNo", dataParts[3]);
            await prefs.setString("UCode", dataParts[4]);
            await prefs.setString("O_Name", dataParts[5]);
            await prefs.setString("D_Database", dataParts[6]);
            await prefs.setString("AutoAllot", dataParts[7]);
            await prefs.setString("WAPP", dataParts[8]);
            await prefs.setString("Architect", dataParts[9]);
            await prefs.setString("Arch_Name", dataParts[10]);
            await prefs.setString("Grade", dataParts[11]);
            await prefs.setString("LogoURL", dataParts[12]);
            await prefs.setString("showAllCustomer", dataParts[13]);
            await prefs.setString("BaseCity", dataParts[14]);
            await prefs.setString("Hide_Activity", dataParts[15]);
            await prefs.setString("Hide_Executive", dataParts[16]);
            await prefs.setString("Hide_FDATE", dataParts[17]);
            await prefs.setString("Hide_OldCust", dataParts[18]);
            await prefs.setString("Quotation", dataParts[19]);
            await prefs.setString("Quote_History", dataParts[20]);
            await prefs.setString("Enable_PrePostSale", dataParts[21]);
            await prefs.setString("EnableProd_Rep", dataParts[22]);
            await prefs.setString("EnableAct_Rep", dataParts[23]);

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CustomerScreen()),
            );
          } else {
            setState(() {
              _errorMessage = 'Incomplete data received from server.';
            });
          }
        } else {
          setState(() {
            _errorMessage = rawData.isNotEmpty ? rawData : 'Invalid credentials. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect to the server. Check your internet connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF170214), Color(0xFF44073A), Color(0xFF111827)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Area
                  // To this:
Image.asset(
                    'assets/images/mda_logo.png',
                    height: 60,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.favorite,
                        size: 60,
                        color: mdaPrimaryBlue,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '',
                    style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // ERROR MESSAGE UI (Added back!)
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
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Floating Label Inputs
                  _buildFloatingField(_clientIdController, 'Client ID'),
                  const SizedBox(height: 24),
                  _buildFloatingField(_usernameController, 'User ID / Email ID'),
                  const SizedBox(height: 24),
                  _buildFloatingField(_passwordController, 'Password', isPassword: true),
                  const SizedBox(height: 32),

                  // Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C61E1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Custom widget for floating labels
  Widget _buildFloatingField(TextEditingController controller, String label, {bool isPassword = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: mdaInputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              // Added the eye icon back for passwords
              suffixIcon: isPassword ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[500],
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ) : null,
            ),
          ),
        ),
        Positioned(
          top: -10,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCA38CA), 
              ),
            ),
          ),
        ),
      ],
    );
  }
}