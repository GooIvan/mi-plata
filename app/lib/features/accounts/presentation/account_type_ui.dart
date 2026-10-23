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
}
