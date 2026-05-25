import 'package:flutter/material.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';

/// Standard scaffold for all top-level screens.
///
/// Using this widget guarantees that the AppBar picks up the user-configured
/// top-bar colour from [AppBarTheme] (set in main.dart via themeNotifier) and
/// never hard-codes a colour. Always prefer this over writing a raw [Scaffold]
/// + [AppBar] in a new screen.
class AppMainScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final List<Widget> extraActions;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  const AppMainScaffold({
    super.key,
    required this.title,
    required this.body,
    this.drawer,
    this.floatingActionButton,
    this.extraActions = const [],
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: backgroundColor ?? cs.surfaceContainerLowest,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: [...extraActions, const AppUserMenu()],
      ),
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
