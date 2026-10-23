import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../debts/domain/debt.dart';
import '../../debts/presentation/debts_providers.dart';
import '../domain/currency_converter.dart';
import 'currency_error_message.dart';
import 'currency_providers.dart';
import 'currency_ui.dart';
import 'widgets/rate_form_sheet.dart';

/// Las tasas de cambio: cuánto vale cada moneda en la moneda base.
///
/// Se listan las monedas que el usuario usa (en cuentas o deudas) y las que ya
/// tienen tasa, las que faltan primero.
class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final converter = ref.watch(currencyConverterProvider);
    final accounts = ref.watch(accountsProvider).value;
    final debts = ref.watch(debtsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ratesTitle)),
      body: converter.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: currencyErrorMessage(l10n, error),
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(currencyConverterProvider),
        ),
        data: (data) {
          // Las que usa el usuario y las que ya tienen tasa, menos la base.
          final currencies = {
            for (final account in accounts ?? const <Account>[])
              if (!account.isArchived) account.currency,
            for (final debt in debts ?? const <Debt>[])
              if (!debt.isArchived) debt.currency,
            ...data.rates.keys,
          }..remove(data.base);
          final sorted = currencies.toList()
            ..sort((a, b) {
              final byMissing = (data.canConvert(a) ? 1 : 0).compareTo(
                data.canConvert(b) ? 1 : 0,
              );
              return byMissing != 0 ? byMissing : a.compareTo(b);
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.ratesIntro(data.base),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    l10n.ratesEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final currency in sorted)
                        _RateTile(currency: currency, converter: data),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRateForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.ratesAdd),
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  const _RateTile({required this.currency, required this.converter});

  final String currency;
  final CurrencyConverter converter;

  /// "Actualizada hoy", "ayer" o "hace 3 días".
  String _updated(BuildContext context, DateTime updatedAt) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(updatedAt.year, updatedAt.month, updatedAt.day))
        .inDays;
    if (days <= 0) return l10n.ratesUpdatedToday;
    if (days == 1) return l10n.ratesUpdatedYesterday;
    return l10n.ratesUpdatedDaysAgo(days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rate = converter.rates[currency];

    return ListTile(
      leading: CircleAvatar(
        child: Text(currency, style: theme.textTheme.labelSmall),
      ),
      title: Text(currencyOptionLabel(l10n, currency)),
      subtitle: rate == null
          ? Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 14,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(l10n.ratesNoRate),
              ],
            )
          : Text(
              '${l10n.ratesOneEquals(currency, context.formats.money(rate.rate, currency: converter.base))}'
              ' · ${_updated(context, rate.updatedAt)}',
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showRateForm(context, currency: currency),
    );
  }
}
