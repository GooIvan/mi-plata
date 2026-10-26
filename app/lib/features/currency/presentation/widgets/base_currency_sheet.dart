import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/currency.dart';
import '../../domain/rate_parser.dart';
import '../currency_error_message.dart';
import '../currency_providers.dart';
import '../currency_ui.dart';

/// Abre la hoja para elegir la moneda base.
Future<void> showBaseCurrencySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const BaseCurrencySheet(),
  );
}

class BaseCurrencySheet extends ConsumerStatefulWidget {
  const BaseCurrencySheet({super.key});

  @override
  ConsumerState<BaseCurrencySheet> createState() => _BaseCurrencySheetState();
}

class _BaseCurrencySheetState extends ConsumerState<BaseCurrencySheet> {
  final _formKey = GlobalKey<FormState>();
  final _rate = TextEditingController();
  String? _selected;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  /// Al elegir otra moneda se precarga la tasa que ya tenga.
  void _select(String code, String base) {
    final rate = ref.read(currencyConverterProvider).value?.rates[code];
    setState(() {
      _selected = code;
      _error = null;
      _rate.text = code == base || rate == null
          ? ''
          : RateParser.toInput(rate.rate, context.formats);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(currencyConverterProvider.notifier);
    final text = _rate.text.trim();
    final rate = text.isEmpty ? null : RateParser.parse(text, context.formats);

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await notifier.setBase(_selected!, rate: rate);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = currencyErrorMessage(context.l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final base = ref.watch(currencyConverterProvider).value?.base ?? defaultCurrency;
    final selected = _selected ?? base;
    final changing = selected != base;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.baseCurrencyTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              l10n.baseCurrencyIntro,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              items: [
                for (final option in supportedCurrencies)
                  DropdownMenuItem(
                    value: option.code,
                    child: Text(
                      currencyOptionLabel(l10n, option.code),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (code) {
                      if (code != null) _select(code, base);
                    },
              decoration: InputDecoration(
                labelText: l10n.settingsBaseCurrency,
                border: const OutlineInputBorder(),
              ),
            ),
            if (changing) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _rate,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                // Vacía vale: solo hace falta si hay tasas o presupuestos que
                // convertir, y entonces lo dice la base de datos.
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        RateParser.parse(value, context.formats) != null
                    ? null
                    : l10n.ratesFormInvalid,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.baseCurrencyRateLabel(selected, base),
                  helperText: l10n.baseCurrencyRateHelp(selected),
                  helperMaxLines: 2,
                  hintText: l10n.ratesFormHint,
                  suffixText: base,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || !changing ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.baseCurrencyChangeButton),
            ),
          ],
        ),
      ),
    );
  }
}
