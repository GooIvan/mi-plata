import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../domain/account_type.dart';

extension AccountTypeUi on AccountType {
  String label(AppLocalizations l10n) => switch (this) {
    AccountType.cash => l10n.accountTypeCash,
    AccountType.bank => l10n.accountTypeBank,
    AccountType.wallet => l10n.accountTypeWallet,
    AccountType.card => l10n.accountTypeCard,
  };

  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.wallet => Icons.account_balance_wallet_outlined,
    AccountType.card => Icons.credit_card_outlined,
  };

  /// Un color para cada tipo, para reconocerlas de un vistazo.
  Color color(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      AccountType.cash => dark ? const Color(0xFF3DD6A0) : const Color(0xFF0E9F6E),
      AccountType.bank => dark ? const Color(0xFF7DA5FF) : const Color(0xFF3E7BFA),
      AccountType.wallet => dark ? const Color(0xFFB79CFF) : const Color(0xFF7C4DFF),
      AccountType.card => dark ? const Color(0xFFFFB066) : const Color(0xFFE8730C),
    };
  }
}
