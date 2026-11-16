import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';

/// What the dialog came back with: a number to set, or the anchor to go.
sealed class DiveNumberChoice {
  const DiveNumberChoice();
}

class SetDiveNumber extends DiveNumberChoice {
  const SetDiveNumber(this.number);
  final int number;
}

class ClearDiveNumber extends DiveNumberChoice {
  const ClearDiveNumber();
}

/// Asks for the logbook number of one dive. Null when cancelled.
///
/// [current] is what the dive shows now, counted or not, so confirming an
/// already right number is one tap. [canClear] only when this very dive
/// carries a number set by hand - a counted one has nothing to remove.
Future<DiveNumberChoice?> showDiveNumberDialog(
  BuildContext context, {
  int? current,
  bool canClear = false,
}) => showDialog<DiveNumberChoice>(
  context: context,
  builder: (_) => _DiveNumberDialog(current: current, canClear: canClear),
);

class _DiveNumberDialog extends StatefulWidget {
  const _DiveNumberDialog({this.current, this.canClear = false});

  final int? current;
  final bool canClear;

  @override
  State<_DiveNumberDialog> createState() => _DiveNumberDialogState();
}

class _DiveNumberDialogState extends State<_DiveNumberDialog> {
  late final _field = TextEditingController(
    text: widget.current?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final number = int.tryParse(_field.text.trim());
    if (number == null || number < 1) {
      setState(() => _error = AppStrings.of(context).diveNumberInvalid);
      return;
    }
    Navigator.of(context).pop(SetDiveNumber(number));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AlertDialog(
      title: Text(s.diveNumberSet),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.diveNumberSetBody),
          const SizedBox(height: 16),
          TextField(
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: s.diveNumberLabel,
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        if (widget.canClear)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const ClearDiveNumber()),
            child: Text(s.remove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(s.save)),
      ],
    );
  }
}
