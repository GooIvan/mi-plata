import 'package:flutter/material.dart';

/// El símbolo de Mi Plata (la billetera con las monedas), sin texto. Es el mismo
/// dibujo del ícono de la app. El texto "Mi Plata" va aparte, escrito con la
/// tipografía de la app.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 32});

  /// El nombre de la app, tal como se escribe.
  static const appName = 'Mi Plata';

  /// Dónde está la imagen (la única de `assets/branding/` que se empaqueta).
  static const asset = 'assets/branding/simbolo-color-recortado.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // Un dibujo, no información: el nombre ya va escrito al lado.
      excludeFromSemantics: true,
    );
  }
}
