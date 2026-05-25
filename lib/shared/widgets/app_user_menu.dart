import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mda_crm/features/authentication/presentation/screens/login_screen.dart';
import 'package:mda_crm/shared/theme/theme_notifier.dart';
import 'package:mda_crm/shared/utils/app_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

/// Shared AppBar user menu used across all screens.
/// Drop it into any AppBar's `actions` list as `const AppUserMenu()`.
class AppUserMenu extends StatefulWidget {
  const AppUserMenu({super.key});

  @override
  State<AppUserMenu> createState() => _AppUserMenuState();
}

class _AppUserMenuState extends State<AppUserMenu> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userName = prefs.getString('UName') ?? '');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showChangePasswordDialog() {
    final cs = Theme.of(context).colorScheme;
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isSaving = false;
    String? errorMsg;
    bool showNew = false;
    bool showConfirm = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Icon(Icons.lock_outline, color: mdaPrimaryBlue),
            const SizedBox(width: 8),
            const Text('Change Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(errorMsg!,
                      style: TextStyle(
                          color: cs.onErrorContainer, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: newPassCtrl,
                obscureText: !showNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        showNew ? Icons.visibility : Icons.visibility_off,
                        size: 20),
                    onPressed: () => setDialog(() => showNew = !showNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassCtrl,
                obscureText: !showConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        showConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 20),
                    onPressed: () =>
                        setDialog(() => showConfirm = !showConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: mdaPrimaryBlue),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mdaPrimaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () async {
                      final newPass = newPassCtrl.text.trim();
                      final confirmPass = confirmPassCtrl.text.trim();
                      if (newPass.isEmpty) {
                        setDialog(() =>
                            errorMsg = 'Please enter a new password.');
                        return;
                      }
                      if (newPass != confirmPass) {
                        setDialog(
                            () => errorMsg = 'Passwords do not match.');
                        return;
                      }
                      setDialog(() {
                        isSaving = true;
                        errorMsg = null;
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final response = await http.post(
                          Uri.parse(
                              'https://webservices.mdapulse.com/Dashboard.aspx/ChangePassword'),
                          headers: {
                            'Content-Type': 'application/json; charset=utf-8'
                          },
                          body: jsonEncode({
                            'ClientId': prefs.getString('CLIENTID') ?? '',
                            'Pass': newPass,
                            'sno': int.tryParse(
                                    prefs.getString('sno') ?? '0') ??
                                0,
                            'DB': prefs.getString('D_Database') ?? '',
                          }),
                        );
                        if (response.statusCode == 200 &&
                            jsonDecode(response.body)['d']?.toString() ==
                                '1') {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;
                          showAppDialog(context,
                              type: DialogType.success,
                              title: 'Password Changed',
                              message:
                                  'Your password has been updated successfully.');
                        } else {
                          setDialog(() {
                            isSaving = false;
                            errorMsg = 'Failed to update. Please try again.';
                          });
                        }
                      } catch (_) {
                        setDialog(() {
                          isSaving = false;
                          errorMsg = 'Network error. Check your connection.';
                        });
                      }
                    },
                    child: const Text('Update Password'),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _userName.isNotEmpty ? _userName : 'User',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.account_circle, size: 32, color: cs.onSurface),
            Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'darkmode',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dark_mode, size: 18),
                SizedBox(width: 8),
                Text('Dark Mode'),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'changepassword',
          child: Row(children: [
            Icon(Icons.lock_outline, size: 20),
            SizedBox(width: 12),
            Text('Change Password'),
          ]),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 12),
            Text('Logout'),
          ]),
        ),
      ],
      onSelected: (value) async {
        if (value == 'darkmode') {
          final newVal = !themeNotifier.value.isDarkMode;
          await themeNotifier.updateTheme(isDarkMode: newVal);
        } else if (value == 'changepassword') {
          _showChangePasswordDialog();
        } else if (value == 'logout') {
          _logout();
        }
      },
    );
  }
}
