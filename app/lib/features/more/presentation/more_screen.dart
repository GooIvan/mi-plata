import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/finance_colors.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../l10n/l10n.dart';

/// Lo que no cabe en la barra de navegación: resumen, presupuestos, deudas,
/// pagos recurrentes, categorías y ajustes.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = context.finance;
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget entry(IconData icon, Color color, String title, String route) =>
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: IconBadge(icon: icon, color: color),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Column(
              children: [
                entry(
                  Icons.insights_outlined,
                  finance.income,
                  l10n.summaryTitle,
                  AppRoutes.summary,
                ),
                entry(
                  Icons.pie_chart_outline,
                  finance.warning,
                  l10n.budgetsTitle,
                  AppRoutes.budgets,
                ),
                entry(
                  Icons.handshake_outlined,
                  finance.transfer,
                  l10n.debtsTitle,
                  AppRoutes.debts,
                ),
                entry(
                  Icons.autorenew,
                  dark ? const Color(0xFFB79CFF) : const Color(0xFF7C4DFF),
                  l10n.recurringTitle,
                  AppRoutes.recurring,
                ),
                entry(
                  Icons.category_outlined,
                  dark ? const Color(0xFFFF8AB4) : const Color(0xFFD6336C),
                  l10n.categoriesTitle,
                  AppRoutes.categories,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: entry(
              Icons.settings_outlined,
              Theme.of(context).colorScheme.onSurfaceVariant,
              l10n.settingsTitle,
              AppRoutes.settings,
            ),
          ),
        ],
      ),
    );
  }
}
