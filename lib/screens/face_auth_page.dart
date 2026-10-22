import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../models/auth_stage.dart';
import '../services/auth_api_service.dart';
import '../services/video_capture_service.dart';
import '../widgets/camera_preview_area.dart';
import '../widgets/header.dart';
import '../widgets/status_banner.dart';

/// Tela principal de verificação facial: exibe a pré-visualização da
/// câmera e conduz o fluxo de captura e verificação do vídeo pela API.
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

  final VideoCaptureService _videoCaptureService = VideoCaptureService();
  final AuthApiService _authApiService = AuthApiService();

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
  }

  @override
  void dispose() {
    _controller?.dispose();
    _authApiService.dispose();
    super.dispose();
  }

  bool get _isProcessing => _stage != AuthStage.idle;

  String get _statusMessage {
    switch (_stage) {
      case AuthStage.idle:
        return "Posicione seu rosto dentro da moldura.";
      case AuthStage.scanning:
        return "Mantenha-se imóvel, gravando vídeo de 5 segundos...";
      case AuthStage.analyzing:
        return "Validando sinais biológicos...";
    }
  }

  Future<void> _processAuthentication() async {
    if (_isProcessing || _controller == null) return;

    setState(() => _stage = AuthStage.scanning);

    XFile? capturedFile;
    try {
      await _initializeControllerFuture;
      final result = await _videoCaptureService.recordVideo(_controller!);
      capturedFile = result.sourceFile;

      if (!mounted) return;
      setState(() => _stage = AuthStage.analyzing);
      final verification = await _authApiService.authenticate(capturedFile);
      if (!mounted) return;
      _showResult(
        verification.isApproved,
        message: verification.apiMessage,
        code: verification.payload?.code ?? verification.errorCode,
      );
    } catch (e) {
      if (!mounted) return;
      _showResult(false, message: _userFacingError(e));
    } finally {
      if (capturedFile != null) {
        await _videoCaptureService.discard(capturedFile);
      }
      if (mounted) {
        setState(() => _stage = AuthStage.idle);
      }
    }
  }

  String _userFacingError(Object error) {
    if (error is AuthenticationApiException) return error.message;
    return "Não foi possível comunicar com a API de autenticação.";
  }

  void _showResult(bool success, {String? message, String? code}) {
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
        title: Text(success ? "Acesso autorizado" : "Resultado da verificação"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message ?? "", textAlign: TextAlign.center),
            if (code != null && code.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                "Código: $code",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
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
                    const Header(
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
                              child: CameraPreviewArea(
                                controller: _controller,
                                initializeFuture: _initializeControllerFuture,
                                stage: _stage,
                              ),
                            ),
                            const SizedBox(height: 18),
                            StatusBanner(
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
