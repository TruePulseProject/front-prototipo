import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/auth_stage.dart';

/// Área de pré-visualização da câmera com máscara oval, moldura de rosto
/// e linha de escaneamento animada durante a captura.
class CameraPreviewArea extends StatefulWidget {
  final CameraController? controller;
  final Future<void>? initializeFuture;
  final AuthStage stage;

  const CameraPreviewArea({
    super.key,
    required this.controller,
    required this.initializeFuture,
    required this.stage,
  });

  @override
  State<CameraPreviewArea> createState() => _CameraPreviewAreaState();
}

class _CameraPreviewAreaState extends State<CameraPreviewArea>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isProcessing = widget.stage != AuthStage.idle;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111827), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: widget.controller == null
            ? const NoCameraPlaceholder()
            : Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  FutureBuilder<void>(
                    future: widget.initializeFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width:
                                widget.controller!.value.previewSize?.height ??
                                1,
                            height:
                                widget.controller!.value.previewSize?.width ??
                                1,
                            child: CameraPreview(widget.controller!),
                          ),
                        );
                      }
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      );
                    },
                  ),
                  // Dark vignette mask
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: OvalMaskPainter(
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ),
                  // Animated scan line
                  if (isProcessing)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: ScanLinePainter(
                                progress: _scanController.value,
                                color: colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Oval frame + corner brackets
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final pulse = isProcessing
                            ? 0.7 + (_pulseController.value * 0.3)
                            : 1.0;
                        return CustomPaint(
                          size: Size.infinite,
                          painter: FacePainter(
                            color: isProcessing
                                ? colorScheme.primary
                                : Colors.white,
                            opacity: pulse,
                            highlight: isProcessing,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Placeholder exibido quando não há câmera disponível no dispositivo.
class NoCameraPlaceholder extends StatelessWidget {
  const NoCameraPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              color: Colors.white.withOpacity(0.6),
              size: 56,
            ),
            const SizedBox(height: 14),
            const Text(
              "Câmera desativada",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Utilize um dispositivo físico\ncom câmera frontal",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinta a máscara escura fora da região oval do rosto (vinheta).
class OvalMaskPainter extends CustomPainter {
  final Color color;
  OvalMaskPainter({required this.color});

  Rect _ovalRect(Size size) {
    final w = size.width * 0.62;
    final h = size.height * 0.72;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()..addOval(_ovalRect(size));
    final mask = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(mask, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant OvalMaskPainter old) => old.color != color;
}

/// Pinta a moldura oval e os cantos de destaque sobre o rosto.
class FacePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final bool highlight;

  FacePainter({
    required this.color,
    required this.opacity,
    required this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.62;
    final h = size.height * 0.72;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );

    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawOval(rect, paint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const bracketLength = 22.0;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final dx = (i.isEven ? 1 : -1).toDouble();
      final dy = (i < 2 ? 1 : -1).toDouble();
      canvas.drawLine(c, c.translate(bracketLength * dx, 0), bracketPaint);
      canvas.drawLine(c, c.translate(0, bracketLength * dy), bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter old) =>
      old.opacity != opacity ||
      old.color != color ||
      old.highlight != highlight;
}

/// Pinta a linha de escaneamento animada que percorre a área do rosto.
class ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.62;
    final h = size.height * 0.72;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );

    canvas.save();
    final clip = Path()..addOval(rect);
    canvas.clipPath(clip);

    final y = rect.top + (rect.height * progress);
    final lineRect = Rect.fromLTWH(rect.left, y - 18, rect.width, 36);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0),
          color.withOpacity(0.6),
          color.withOpacity(0),
        ],
      ).createShader(lineRect);

    canvas.drawRect(lineRect, paint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter old) =>
      old.progress != progress || old.color != color;
}
