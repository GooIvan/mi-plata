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

/// Abre la hoja para definir cuánto vale una moneda en la moneda base. Con
/// [currency] la moneda ya está elegida; sin ella se elige de la lista.
Future<void> showRateForm(BuildContext context, {String? currency}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => RateFormSheet(currency: currency),
  );
}

class RateFormSheet extends ConsumerStatefulWidget {
  const RateFormSheet({super.key, this.currency});

  final String? currency;

  @override
  ConsumerState<RateFormSheet> createState() => _RateFormSheetState();
}

class _RateFormSheetState extends ConsumerState<RateFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _rate = TextEditingController();
  late String? _currency = widget.currency;
  bool _filled = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  /// Precarga la tasa que ya tiene la moneda elegida (si tiene).
  void _prefill() {
    final rate = ref.read(currencyConverterProvider).value?.rates[_currency];
    _rate.text = rate == null ? '' : RateParser.toInput(rate.rate, context.formats);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filled) {
      _filled = true;
      _prefill();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = currencyErrorMessage(context.l10n, error);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(currencyConverterProvider.notifier);
    final rate = RateParser.parse(_rate.text, context.formats)!;
    await _run(() => notifier.setRate(_currency!, rate));
  }

  Future<void> _remove() async {
    final notifier = ref.read(currencyConverterProvider.notifier);
    await _run(() => notifier.deleteRate(_currency!));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final converter = ref.watch(currencyConverterProvider).value;
    final base = converter?.base ?? defaultCurrency;
    final hasRate = converter?.rates.containsKey(_currency) ?? false;
    final fixed = widget.currency != null;

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
            Text(
              fixed
                  ? l10n.ratesFormTitle(widget.currency!)
                  : l10n.ratesAdd,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (!fixed) ...[
              DropdownButtonFormField<String>(
                initialValue: _currency,
                isExpanded: true,
                items: [
                  for (final option in supportedCurrencies)
                    if (option.code != base)
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
                    : (code) => setState(() {
                        _currency = code;
                        _prefill();
                      }),
                validator: (code) =>
                    code == null ? l10n.ratesFormChooseCurrency : null,
                decoration: InputDecoration(
                  labelText: l10n.currencyLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _rate,
              enabled: !_saving,
              autofocus: fixed,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: (value) => RateParser.parse(value, context.formats) == null
                  ? l10n.ratesFormInvalid
                  : null,
              onFieldSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: l10n.ratesFormAmountLabel(_currency ?? '…'),
                hintText: l10n.ratesFormHint,
                suffixText: base,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.commonSave),
            ),
            if (hasRate) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _remove,
                child: Text(
                  l10n.ratesFormRemove,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
