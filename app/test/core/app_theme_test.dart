import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_plata/core/theme/app_theme.dart';
import 'package:mi_plata/core/theme/finance_colors.dart';
import 'package:mi_plata/features/accounts/domain/account_type.dart';
import 'package:mi_plata/features/accounts/presentation/account_type_ui.dart';

/// La razón de contraste de WCAG entre dos colores (de 1 a 21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final themes = {'claro': AppTheme.light, 'oscuro': AppTheme.dark};

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    group('tema $name', () {
      test('usa la tipografía de la app en todos los estilos', () {
        for (final style in [
          theme.textTheme.displaySmall,
          theme.textTheme.titleLarge,
          theme.textTheme.titleMedium,
          theme.textTheme.bodyMedium,
          theme.textTheme.labelSmall,
        ]) {
          expect(style?.fontFamily, AppTheme.fontFamily);
        }
      });

      test('trae los colores del dinero', () {
        expect(theme.extension<FinanceColors>(), isNotNull);
      });

      test(
        'el texto sobre el degradado principal se lee (contraste 4,5 o más)',
        () {
          final finance = theme.extension<FinanceColors>()!;
          for (final color in [
            ...finance.heroGradient,
            ...finance.heroLossGradient,
          ]) {
            expect(contrast(finance.onHero, color), greaterThanOrEqualTo(4.5));
          }
        },
      );

      test('los montos de ingreso y gasto se leen sobre las tarjetas', () {
        final finance = theme.extension<FinanceColors>()!;
        final card = theme.colorScheme.surfaceContainerLowest;
        for (final color in [
          finance.income,
          finance.expense,
          finance.transfer,
        ]) {
          expect(contrast(color, card), greaterThanOrEqualTo(3));
        }
      });

      test('los colores de cada tipo de cuenta se leen sobre las tarjetas', () {
        final card = theme.colorScheme.surfaceContainerLowest;
        for (final type in AccountType.values) {
          expect(
            contrast(type.color(theme.brightness), card),
            greaterThanOrEqualTo(3),
            reason: '${type.name} en $name',
          );
        }
      });

      test('las tarjetas se despegan del fondo', () {
        expect(
          theme.colorScheme.surfaceContainerLowest,
          isNot(theme.scaffoldBackgroundColor),
        );
      });
    });
  }

  test(
    'los colores del dinero se mezclan sin errores entre claro y oscuro',
    () {
      final middle = FinanceColors.light.lerp(FinanceColors.dark, 0.5);
      expect(
        middle.heroGradient.length,
        FinanceColors.light.heroGradient.length,
      );
      expect(FinanceColors.light.lerp(null, 0.5), FinanceColors.light);
    },
  );
}
