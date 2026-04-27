// File: lib/shared/widgets/app_drawer.dart

import 'package:flutter/material.dart';

import 'package:mda_crm/features/client_management/presentation/screens/customer_screen.dart';
import 'package:mda_crm/features/task_management/presentation/screens/task_screen.dart';
import 'package:mda_crm/features/employee_management/presentation/screens/employee_screen.dart';
import 'package:mda_crm/features/settings/presentation/screens/setting_screen.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  final String companyName;

  const AppDrawer({
    super.key,
    required this.currentRoute,
    required this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: mdaPrimaryBlue,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/images/mda_logo.png',
                      height: 32,
                      width: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      companyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.show_chart,
                    title: 'Dashboard',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people,
                    title: 'Customer',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.description,
                    title: 'Reports',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.assignment,
                    title: 'Tasks',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.request_quote,
                    title: 'Quotation',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.work,
                    title: 'Employee',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.email,
                    title: 'Messaging',
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings,
                    title: 'Settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final bool isSelected = currentRoute == title;
    return Container(
      color: isSelected ? Colors.white : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? mdaPrimaryBlue : Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? mdaPrimaryBlue : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (!isSelected) {
            Widget? nextScreen;
            if (title == 'Customer') {
              nextScreen = CustomerScreen();
            } else if (title == 'Tasks') {
              nextScreen = TaskScreen();
            } else if (title == 'Employee') {
              nextScreen = EmployeeScreen();
            } else if (title == 'Settings') {
              nextScreen = SettingScreen();
            }

            if (nextScreen != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => nextScreen!),
              );
            }
          }
        },
      ),
    );
  }
}
