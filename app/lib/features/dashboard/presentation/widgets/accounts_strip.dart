import 'package:flutter/material.dart';

import '../../../../core/format/formats.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/presentation/account_type_ui.dart';

/// Las cuentas activas como tarjetas en una fila que se desliza, cada una con
/// el color de su tipo. Al tocar una abre la lista de cuentas.
class AccountsStrip extends StatelessWidget {
  const AccountsStrip({super.key, required this.accounts, required this.onTap});

  final List<Account> accounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Se desliza hasta el borde de la pantalla, no solo hasta el margen.
        clipBehavior: Clip.none,
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _AccountCard(account: accounts[index], onTap: onTap),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onTap});

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = account.type.color(theme.brightness);
    final negative = account.currentBalance < 0;

    return SizedBox(
      width: 168,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconBadge(icon: account.type.icon, color: color, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.formats.money(
                      account.currentBalance,
                      currency: account.currency,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: negative ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
