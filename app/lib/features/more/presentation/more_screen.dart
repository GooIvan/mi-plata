import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../l10n/l10n.dart';

/// Lo que no cabe en la barra de navegación: resumen, presupuestos, deudas,
/// pagos recurrentes, categorías y ajustes.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget entry(IconData icon, String title, String route) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        children: [
          entry(Icons.insights_outlined, l10n.summaryTitle, AppRoutes.summary),
          entry(Icons.pie_chart_outline, l10n.budgetsTitle, AppRoutes.budgets),
          entry(Icons.handshake_outlined, l10n.debtsTitle, AppRoutes.debts),
          entry(Icons.autorenew, l10n.recurringTitle, AppRoutes.recurring),
          entry(
            Icons.category_outlined,
            l10n.categoriesTitle,
            AppRoutes.categories,
          ),
          const Divider(),
          entry(Icons.settings_outlined, l10n.settingsTitle, AppRoutes.settings),
        ],
      ),
    );
  }
}
