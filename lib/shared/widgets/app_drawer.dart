// File: lib/shared/widgets/app_drawer.dart

import 'package:flutter/material.dart';

import 'package:mda_crm/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:mda_crm/features/client_management/presentation/screens/customer_screen.dart';
import 'package:mda_crm/features/task_management/presentation/screens/task_screen.dart';
import 'package:mda_crm/features/employee_management/presentation/screens/employee_screen.dart';
import 'package:mda_crm/features/settings/presentation/screens/setting_screen.dart';
import 'package:mda_crm/features/reports/presentations/screens/reports_screen.dart';
import 'package:mda_crm/features/workflow/presentation/screens/workflow_screen.dart';
import 'package:mda_crm/features/quotation/presentation/screens/quotation_screen.dart';
import 'package:mda_crm/features/messaging/presentation/screens/messaging_screen.dart';
import 'package:mda_crm/shared/theme/theme_notifier.dart';

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
    return ValueListenableBuilder<ThemeState>(
      valueListenable: themeNotifier,
      builder: (context, themeState, _) {
        final sidebarColor = themeState.sidebarColor;
        return Drawer(
          backgroundColor: sidebarColor,
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
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.people,
                    title: 'Customer',
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.description,
                    title: 'Reports',
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.assignment,
                    title: 'Tasks',
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.request_quote,
                    title: 'Quotation',
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.work,
                    title: 'Employee',
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.account_tree_outlined,
                    title: 'Workflows',
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.email,
                    title: 'Messaging',
                    sidebarColor: sidebarColor,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.settings,
                    title: 'Settings',
                    sidebarColor: sidebarColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color sidebarColor,
  }) {
    final bool isSelected = currentRoute == title;
    return Container(
      color: isSelected ? Colors.white : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? sidebarColor : Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? sidebarColor : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          if (!isSelected) {
            Widget? nextScreen;
            if (title == 'Dashboard') {
              nextScreen = const DashboardScreen();
            } else if (title == 'Customer') {
              nextScreen = CustomerScreen();
            } else if (title == 'Reports') {
              nextScreen = const ReportsScreen();
            } else if (title == 'Tasks') {
              nextScreen = TaskScreen();
            } else if (title == 'Employee') {
              nextScreen = EmployeeScreen();
            } else if (title == 'Quotation') {
              nextScreen = const QuotationScreen();
            } else if (title == 'Workflows') {
              nextScreen = const WorkflowScreen();
            } else if (title == 'Messaging') {
              nextScreen = const MessagingScreen();
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
