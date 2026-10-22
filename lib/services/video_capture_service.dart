import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Resultado de uma captura de vídeo: o arquivo temporário gerado pela
/// câmera, que deve ser descartado com [VideoCaptureService.discard] após
/// o envio para a API.
class VideoCaptureResult {
  final Duration duration;
  final XFile sourceFile;

  const VideoCaptureResult({
    required this.duration,
    required this.sourceFile,
  });
}

/// Serviço responsável por gravar um vídeo curto (sem áudio) usando a
/// câmera já inicializada.
///
/// O vídeo não é copiado para o armazenamento do app: o arquivo temporário
/// da câmera é enviado à API do TruePulse e apagado em seguida.
class VideoCaptureService {
  static const Duration defaultDuration = Duration(seconds: 5);

  /// Grava um vídeo pela [duration] informada (padrão: 5 segundos) e
  /// retorna o arquivo temporário e a duração efetiva da gravação.
  Future<VideoCaptureResult> recordVideo(
    CameraController controller, {
    Duration duration = defaultDuration,
  }) async {
    if (!controller.value.isInitialized) {
      throw StateError('A câmera ainda não foi inicializada.');
    }
    if (controller.value.isRecordingVideo) {
      throw StateError('Já existe uma gravação em andamento.');
    }

    await controller.startVideoRecording();
    await Future.delayed(duration);
    final XFile rawFile = await controller.stopVideoRecording();

    return VideoCaptureResult(duration: duration, sourceFile: rawFile);
  }

  /// Apaga o arquivo temporário gerado pela câmera. Na web o vídeo fica
  /// só em memória (blob), então não há arquivo para remover.
  Future<void> discard(XFile file) async {
    if (kIsWeb) return;
    try {
      final tempFile = File(file.path);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } on FileSystemException {
      // Falhar ao apagar o temporário não deve interromper a autenticação.
    }
  }
}
