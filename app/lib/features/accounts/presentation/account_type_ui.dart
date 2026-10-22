import 'package:flutter/material.dart';

import '../domain/account_type.dart';

extension AccountTypeUi on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Efectivo',
    AccountType.bank => 'Banco',
    AccountType.wallet => 'Billetera digital',
    AccountType.card => 'Tarjeta',
  };

  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.wallet => Icons.account_balance_wallet_outlined,
    AccountType.card => Icons.credit_card_outlined,
  };
}
