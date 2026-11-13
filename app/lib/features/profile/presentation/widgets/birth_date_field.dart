import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/profile_validators.dart';

/// El campo de la fecha de nacimiento: se elige con un selector (no se escribe)
/// y se puede quitar. Se usa en el registro y en el perfil.
class BirthDateField extends StatelessWidget {
  const BirthDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? errorText;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: ProfileValidators.earliestBirthDate,
      lastDate: now,
      helpText: context.l10n.profileBirthDateLabel,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.l10n.profileBirthDateLabel,
          errorText: errorText,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: context.l10n.profileBirthDateClear,
                  icon: const Icon(Icons.close),
                  onPressed: enabled ? () => onChanged(null) : null,
                ),
        ),
        child: Text(value == null ? '' : context.formats.fullDate(value!)),
      ),
    );
  }
}
