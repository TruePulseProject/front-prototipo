import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Erro ao buscar câmeras: $e");
  }

  CameraDescription? selectedCamera;
  if (cameras.isNotEmpty) {
    selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
  }

  runApp(TruePulseApp(camera: selectedCamera));
}

class TruePulseApp extends StatelessWidget {
  final CameraDescription? camera;

  const TruePulseApp({super.key, this.camera});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF0056D2);
    return MaterialApp(
      title: 'TruePulse Auth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: FaceAuthPage(camera: camera),
    );
  }
}

enum AuthStage { idle, scanning, analyzing }

class FaceAuthPage extends StatefulWidget {
  final CameraDescription? camera;

  const FaceAuthPage({super.key, this.camera});

  @override
  State<FaceAuthPage> createState() => _FaceAuthPageState();
}

class _FaceAuthPageState extends State<FaceAuthPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  AuthStage _stage = AuthStage.idle;

  // Mock de batimentos cardíacos (será substituído pela resposta da API)
  final Random _random = Random();
  Timer? _bpmTimer;
  int _bpm = 72;
  static const int _historyLength = 40;
  final List<int> _bpmHistory = List<int>.filled(_historyLength, 72);

  @override
  void initState() {
    super.initState();

    if (widget.camera != null) {
      _controller = CameraController(
        widget.camera!,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _initializeControllerFuture = _controller!.initialize();
    }

    _startBpmMock();
  }

  void _startBpmMock() {
    _bpmTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;
      setState(() {
        // Em repouso: ~70 bpm. Durante captura/análise: sobe para ~95 bpm.
        final base = _isProcessing ? 95 : 72;
        final next = (base + _random.nextInt(9) - 4).clamp(50, 130);
        _bpm = next;
        _bpmHistory.removeAt(0);
        _bpmHistory.add(next);
      });
    });
  }

  @override
  void dispose() {
    _bpmTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  bool get _isProcessing => _stage != AuthStage.idle;

  String get _statusMessage {
    switch (_stage) {
      case AuthStage.idle:
        return "Posicione seu rosto dentro da moldura.";
      case AuthStage.scanning:
        return "Mantenha-se imóvel, capturando imagem...";
      case AuthStage.analyzing:
        return "Validando sinais biológicos...";
    }
  }

  Future<void> _processAuthentication() async {
    if (_isProcessing || _controller == null) return;

    setState(() => _stage = AuthStage.scanning);

    try {
      await _initializeControllerFuture;
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() => _stage = AuthStage.analyzing);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      _showResult(true);
    } catch (e) {
      _showResult(false, message: "Erro ao processar a autenticação.");
    } finally {
      if (mounted) {
        setState(() => _stage = AuthStage.idle);
      }
    }
  }

  void _showResult(bool success, {String? message}) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (success ? Colors.green : colorScheme.error).withOpacity(
              0.12,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            success ? Icons.check_rounded : Icons.close_rounded,
            color: success ? Colors.green : colorScheme.error,
            size: 40,
          ),
        ),
        title: Text(success ? "Acesso autorizado" : "Acesso negado"),
        content: Text(
          success
              ? "Prova de vida validada com sucesso pelo TruePulse."
              : (message ??
                    "Não foi possível confirmar a autenticidade biológica."),
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
            child: const Text("Concluir"),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasCamera = widget.camera != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.45),
            colorScheme.surface,
            colorScheme.surface,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "TruePulse",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: "Ajuda",
              onPressed: () {},
              icon: const Icon(Icons.help_outline_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeartRateMonitor(
                      bpm: _bpm,
                      history: _bpmHistory,
                      active: _isProcessing,
                    ),
                    const SizedBox(height: 20),
                    _Header(
                      title: "Verificação facial",
                      subtitle:
                          "Confirme sua identidade com a tecnologia de prova de vida do TruePulse.",
                    ),
                    Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      color: colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AspectRatio(
                              aspectRatio: 3 / 4,
                              child: _CameraPreviewArea(
                                controller: _controller,
                                initializeFuture: _initializeControllerFuture,
                                stage: _stage,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _StatusBanner(
                              message: hasCamera
                                  ? _statusMessage
                                  : "Dispositivo de captura não encontrado.",
                              stage: _stage,
                              hasCamera: hasCamera,
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: (_isProcessing || !hasCamera)
                                  ? null
                                  : _processAuthentication,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: _isProcessing
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.face_retouching_natural),
                              label: Text(
                                _isProcessing
                                    ? "Processando..."
                                    : "Iniciar captura",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final AuthStage stage;
  final bool hasCamera;

  const _StatusBanner({
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

// class _Tips extends StatelessWidget {
//   const _Tips();

//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//     final tips = [
//       (Icons.wb_sunny_outlined, "Boa iluminação"),
//       (Icons.visibility_outlined, "Olhe para a câmera"),
//       (Icons.no_accounts_outlined, "Sem acessórios"),
//     ];

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: tips.map((tip) {
//         return Expanded(
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 4),
//             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//             decoration: BoxDecoration(
//               color: colorScheme.surface,
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(
//                 color: colorScheme.outlineVariant.withOpacity(0.5),
//               ),
//             ),
//             child: Column(
//               children: [
//                 Icon(tip.$1, size: 20, color: colorScheme.primary),
//                 const SizedBox(height: 6),
//                 Text(
//                   tip.$2,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w500,
//                     color: colorScheme.onSurfaceVariant,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }

class _CameraPreviewArea extends StatefulWidget {
  final CameraController? controller;
  final Future<void>? initializeFuture;
  final AuthStage stage;

  const _CameraPreviewArea({
    required this.controller,
    required this.initializeFuture,
    required this.stage,
  });

  @override
  State<_CameraPreviewArea> createState() => _CameraPreviewAreaState();
}

class _CameraPreviewAreaState extends State<_CameraPreviewArea>
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
            ? _NoCameraPlaceholder()
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
                      painter: _OvalMaskPainter(
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
                              painter: _ScanLinePainter(
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
                          painter: _FacePainter(
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

class _NoCameraPlaceholder extends StatelessWidget {
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

class _OvalMaskPainter extends CustomPainter {
  final Color color;
  _OvalMaskPainter({required this.color});

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
  bool shouldRepaint(covariant _OvalMaskPainter old) => old.color != color;
}

class _FacePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final bool highlight;

  _FacePainter({
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
  bool shouldRepaint(covariant _FacePainter old) =>
      old.opacity != opacity ||
      old.color != color ||
      old.highlight != highlight;
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

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
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress || old.color != color;
}

class _HeartRateMonitor extends StatefulWidget {
  final int bpm;
  final List<int> history;
  final bool active;

  const _HeartRateMonitor({
    required this.bpm,
    required this.history,
    required this.active,
  });

  @override
  State<_HeartRateMonitor> createState() => _HeartRateMonitorState();
}

class _HeartRateMonitorState extends State<_HeartRateMonitor>
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
  void didUpdateWidget(covariant _HeartRateMonitor oldWidget) {
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
              painter: _EcgPainter(values: widget.history, color: _accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _EcgPainter({required this.values, required this.color});

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
  bool shouldRepaint(covariant _EcgPainter old) =>
      old.values != values || old.color != color;
}
