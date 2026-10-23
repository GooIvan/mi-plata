import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formats.dart';
import '../../../core/widgets/state_message.dart';
import '../../../l10n/l10n.dart';
import '../domain/debt.dart';
import '../domain/debt_direction.dart';
import '../domain/debt_totals.dart';
import 'debt_detail_screen.dart';
import 'debt_error_message.dart';
import 'debt_form_screen.dart';
import 'debt_ui.dart';
import 'debts_providers.dart';
import 'widgets/debt_tile.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen>
    with SingleTickerProviderStateMixin {
  static const _directions = [DebtDirection.payable, DebtDirection.receivable];

  late final _tabs = TabController(length: _directions.length, vsync: this);
  bool _showArchived = false;

  DebtDirection get _currentDirection => _directions[_tabs.index];

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.debtsTitle),
        actions: [
          IconButton(
            tooltip: _showArchived
                ? l10n.commonHideArchived
                : l10n.commonShowArchived,
            icon: Icon(
              _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final direction in _directions)
              Tab(text: direction.label(l10n)),
          ],
        ),
      ),
      body: debts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StateMessage(
          icon: Icons.cloud_off_outlined,
          text: debtErrorMessage(l10n, error),
          actionLabel: l10n.commonRetry,
          onAction: () => ref.invalidate(debtsProvider),
        ),
        data: (all) => TabBarView(
          controller: _tabs,
          children: [
            for (final direction in _directions) _buildTab(all, direction),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDebtForm(context, direction: _currentDirection),
        icon: const Icon(Icons.add),
        label: Text(l10n.debtsNew),
      ),
    );
  }

  Widget _buildTab(List<Debt> all, DebtDirection direction) {
    final l10n = context.l10n;
    final ofDirection = all.where((debt) => debt.direction == direction).toList();
    final isPayable = direction == DebtDirection.payable;

    if (ofDirection.isEmpty) {
      return StateMessage(
        icon: direction.icon,
        text: isPayable ? l10n.debtsEmptyPayable : l10n.debtsEmptyReceivable,
        actionLabel: l10n.debtsRegister,
        onAction: () => showDebtForm(context, direction: direction),
      );
    }

    // Lo pendiente primero (lo que vence antes, arriba); luego lo saldado y,
    // si se piden, las archivadas.
    final visible = [
      ...ofDirection.where((debt) => !debt.isArchived).toList()
        ..sort(compareDebts),
      if (_showArchived)
        ...ofDirection.where((debt) => debt.isArchived).toList()
          ..sort(compareDebts),
    ];

    if (visible.isEmpty) {
      return StateMessage(
        icon: Icons.inventory_2_outlined,
        text: l10n.debtsAllArchived,
        actionLabel: l10n.commonShowArchived,
        onAction: () => setState(() => _showArchived = true),
      );
    }

    final today = DateTime.now();
    final total = DebtTotals.remainingCents(all, direction);

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        _TotalHeader(
          label: isPayable ? l10n.debtsTotalPayable : l10n.debtsTotalReceivable,
          cents: total,
        ),
        for (final debt in visible) ...[
          DebtTile(
            debt: debt,
            today: today,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DebtDetailScreen(debtId: debt.id),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            context.formats.money(cents / 100),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
