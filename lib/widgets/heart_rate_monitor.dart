import 'dart:math';
import 'package:flutter/material.dart';

/// Cartão que exibe o BPM atual, classificação e um mini gráfico de ECG.
class HeartRateMonitor extends StatefulWidget {
  final int bpm;
  final List<int> history;
  final bool active;

  const HeartRateMonitor({
    super.key,
    required this.bpm,
    required this.history,
    required this.active,
  });

  @override
  State<HeartRateMonitor> createState() => _HeartRateMonitorState();
}

class _HeartRateMonitorState extends State<HeartRateMonitor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartCtrl;

  static const _accent = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: _durationFromBpm(widget.bpm),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  Duration _durationFromBpm(int bpm) {
    // Meio ciclo = sístole/diástole. Duração total ≈ 60s / bpm,
    // animação reverse usa metade.
    final ms = (30000 / bpm.clamp(40, 200)).round();
    return Duration(milliseconds: ms);
  }

  @override
  void didUpdateWidget(covariant HeartRateMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) {
      _heartCtrl.duration = _durationFromBpm(widget.bpm);
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  String _classify(int bpm) {
    if (bpm < 60) return "Bradicardia";
    if (bpm > 100) return "Taquicardia";
    return "Normal";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final classification = _classify(widget.bpm);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.surface, _accent.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _heartCtrl,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_heartCtrl.value);
              final scale = 1.0 + (t * 0.22);
              return Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12 + (t * 0.10)),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: scale,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: _accent,
                    size: 26,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      "Batimentos cardíacos",
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.active
                            ? _accent.withOpacity(0.15)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.active ? "AO VIVO" : "MOCK",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: widget.active
                              ? _accent
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      "${widget.bpm}",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "BPM",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "· $classification",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            height: 48,
            child: CustomPaint(
              painter: EcgPainter(values: widget.history, color: _accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta o traçado estilo ECG a partir do histórico de BPM.
class EcgPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  EcgPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce(min).toDouble();
    final maxV = values.reduce(max).toDouble();
    final range = (maxV - minV) < 1 ? 1.0 : (maxV - minV);

    double xFor(int i) => (i / (values.length - 1)) * size.width;
    double yFor(int v) {
      final norm = (v - minV) / range;
      return size.height - (norm * size.height * 0.8) - (size.height * 0.1);
    }

    final path = Path()..moveTo(xFor(0), yFor(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(xFor(i), yFor(values[i]));
    }

    // Linha de base sutil
    final baseline = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      baseline,
    );

    // Curva do ECG
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    // Ponto luminoso no final
    final lastX = xFor(values.length - 1);
    final lastY = yFor(values.last);
    canvas.drawCircle(
      Offset(lastX, lastY),
      6,
      Paint()..color = color.withOpacity(0.22),
    );
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant EcgPainter old) =>
      old.values != values || old.color != color;
}
