import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shared bar name-entry dialog with live case-insensitive duplicate-name
/// validation. Was previously duplicated (byte-for-byte) as a private
/// widget in both MyBarScreen and FinderScreen. Also used to name a bar at
/// creation time (see [selectAllOnOpen]) rather than auto-naming it and
/// making the user find "Rename" afterwards.
///
/// Note: showDialog<String>() is not disposed eagerly — the dialog's own
/// State disposes its TextEditingController in its own dispose(), which
/// Flutter runs once the dialog's Element is actually unmounted (i.e. once
/// its closing transition has fully finished), not right when showDialog's
/// Future resolves. Disposing earlier than that can throw "A
/// TextEditingController was used after being disposed" if the transition
/// (or the keyboard-hide animation it triggers) rebuilds the TextField on a
/// later frame.
class RenameBarDialog extends StatefulWidget {
  final String initialName;
  final Set<String> existingNamesLower;
  final String title;
  final String confirmLabel;

  /// Pre-selects [initialName] so typing immediately overwrites it — used
  /// for the create-bar dialog, where [initialName] is just a suggestion.
  final bool selectAllOnOpen;

  const RenameBarDialog({
    super.key,
    required this.initialName,
    required this.existingNamesLower,
    this.title = 'Rename Bar',
    this.confirmLabel = 'Save',
    this.selectAllOnOpen = false,
  });

  @override
  State<RenameBarDialog> createState() => _RenameBarDialogState();
}

class _RenameBarDialogState extends State<RenameBarDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialName)
    ..selection = widget.selectAllOnOpen
        ? TextSelection(baseOffset: 0, extentOffset: widget.initialName.length)
        : TextSelection.collapsed(offset: widget.initialName.length);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text(widget.title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Bar name', hintStyle: TextStyle(color: AppTheme.textSecondary)),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            if (widget.existingNamesLower.contains(name.toLowerCase())) {
              setState(() => _error = 'A bar with this name already exists.');
              return;
            }
            Navigator.pop(context, name);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
