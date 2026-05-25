import 'package:flutter/material.dart';

enum DialogType { success, error, warning, info }

Future<void> showAppDialog(
  BuildContext context, {
  required DialogType type,
  required String title,
  required String message,
  String buttonText = 'OK',
}) {
  final config = _dialogConfig(type);

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: config.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: config.iconColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DialogConfig {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final Color buttonColor;
  const _DialogConfig({required this.icon, required this.bgColor, required this.iconColor, required this.buttonColor});
}

_DialogConfig _dialogConfig(DialogType type) {
  switch (type) {
    case DialogType.success:
      return const _DialogConfig(icon: Icons.check_circle_outline, bgColor: Color(0xFFE8F5E9), iconColor: Color(0xFF2E7D32), buttonColor: Color(0xFF2E7D32));
    case DialogType.error:
      return const _DialogConfig(icon: Icons.error_outline, bgColor: Color(0xFFFFEBEE), iconColor: Color(0xFFC62828), buttonColor: Color(0xFFC62828));
    case DialogType.warning:
      return const _DialogConfig(icon: Icons.warning_amber_outlined, bgColor: Color(0xFFFFF8E1), iconColor: Color(0xFFF57F17), buttonColor: Color(0xFFF57F17));
    case DialogType.info:
      return const _DialogConfig(icon: Icons.info_outline, bgColor: Color(0xFFE3F2FD), iconColor: Color(0xFF1565C0), buttonColor: Color(0xFF1565C0));
  }
}
