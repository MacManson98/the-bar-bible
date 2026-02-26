import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

Future<void> showVaultDestructiveSheet(
  BuildContext context, {
  required String itemName,
  required String destructiveLabel,
  required IconData destructiveIcon,
  required VoidCallback onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 2,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              color: AppTheme.surfaceLight,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                itemName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            ListTile(
              leading: Icon(destructiveIcon, color: Colors.redAccent),
              title: Text(
                destructiveLabel,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onConfirm();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textSecondary),
              title: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      );
    },
  );
}
