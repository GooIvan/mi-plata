import '../../../l10n/l10n.dart';
import '../domain/account.dart';

/// Cómo se nombra una cuenta en un selector: su nombre y, si no es de la moneda
/// base, su moneda ("Dólares · USD"); las archivadas, marcadas.
String accountLabel(
  AppLocalizations l10n,
  Account account, {
  String? baseCurrency,
}) {
  final name = baseCurrency != null && account.currency != baseCurrency
      ? '${account.name} · ${account.currency}'
      : account.name;
  return account.isArchived ? l10n.accountsArchivedName(name) : name;
}
