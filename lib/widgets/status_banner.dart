import 'package:flutter/material.dart';
import '../models/auth_stage.dart';

/// Faixa de status exibida abaixo da pré-visualização da câmera,
/// informando o usuário sobre o estágio atual da autenticação.
class StatusBanner extends StatelessWidget {
  final String message;
  final AuthStage stage;
  final bool hasCamera;

  const StatusBanner({
    super.key,
    required this.message,
    required this.stage,
    required this.hasCamera,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    IconData icon;

    if (!hasCamera) {
      bg = colorScheme.errorContainer;
      fg = colorScheme.onErrorContainer;
      icon = Icons.error_outline_rounded;
    } else if (stage == AuthStage.idle) {
      bg = colorScheme.secondaryContainer.withOpacity(0.5);
      fg = colorScheme.onSecondaryContainer;
      icon = Icons.center_focus_strong_rounded;
    } else {
      bg = colorScheme.primaryContainer.withOpacity(0.55);
      fg = colorScheme.onPrimaryContainer;
      icon = Icons.bolt_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
