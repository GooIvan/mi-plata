import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Cuánto dura a la vista un aviso de error.
const errorAlertDuration = Duration(seconds: 3);

OverlayEntry? _current;

/// Muestra [message] como un aviso de error que desaparece solo a los 3
/// segundos (o al tocarlo). Va arriba y **por encima de todo**, también de las
/// hojas y los diálogos: un `SnackBar` normal quedaría detrás de ellos.
///
/// Solo hay uno a la vez: un error nuevo reemplaza al anterior.
void showErrorAlert(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _current?.remove();
  _current = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ErrorAlertView(
      message: message,
      onDone: () {
        if (_current == entry) _current = null;
        entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  // Quien usa un lector de pantalla también se entera.
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
}

/// Muestra [message] como aviso cuando aparece en pantalla (y cada vez que
/// cambia), y no dibuja nada. Sustituye al recuadro fijo de error de los
/// formularios: quien lo usa solo pone `if (error != null) ErrorAlert(error)`.
class ErrorAlert extends StatefulWidget {
  const ErrorAlert(this.message, {super.key});

  final String message;

  @override
  State<ErrorAlert> createState() => _ErrorAlertState();
}

class _ErrorAlertState extends State<ErrorAlert> {
  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void didUpdateWidget(ErrorAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) _show();
  }

  /// Después del cuadro actual: no se puede tocar el Overlay durante `build`.
  void _show() {
    final message = widget.message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showErrorAlert(context, message);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ErrorAlertView extends StatefulWidget {
  const _ErrorAlertView({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_ErrorAlertView> createState() => _ErrorAlertViewState();
}

class _ErrorAlertViewState extends State<_ErrorAlertView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(errorAlertDuration, _dismiss);
  }

  /// Sale con una animación corta y se quita.
  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: top + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _controller,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)),
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: colors.errorContainer,
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _dismiss,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
