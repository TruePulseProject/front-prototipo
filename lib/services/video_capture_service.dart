import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Resultado de uma captura de vídeo: caminho do arquivo salvo
/// no armazenamento local do aplicativo.
class VideoCaptureResult {
  final String filePath;
  final Duration duration;
  final XFile sourceFile;

  const VideoCaptureResult({
    required this.filePath,
    required this.duration,
    required this.sourceFile,
  });
}

/// Serviço responsável por gravar um vídeo curto (sem áudio) usando a
/// câmera já inicializada e salvá-lo no diretório de documentos do app.
///
/// O arquivo capturado também é mantido como [sourceFile] para ser enviado
/// à API do TruePulse sem depender do caminho local da plataforma.
class VideoCaptureService {
  static const Duration defaultDuration = Duration(seconds: 5);

  /// Grava um vídeo pela [duration] informada (padrão: 5 segundos) e
  /// copia o arquivo resultante para o diretório de documentos do app,
  /// retornando o caminho final e a duração efetiva da gravação.
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

    final savedPath = await _saveToAppStorage(rawFile);
    return VideoCaptureResult(
      filePath: savedPath,
      duration: duration,
      sourceFile: rawFile,
    );
  }

  /// Copia o vídeo temporário gerado pela câmera para um arquivo
  /// persistente dentro do diretório de documentos do aplicativo,
  /// nomeado com um timestamp para evitar colisões.
  ///
  /// Em plataformas sem implementação do `path_provider`, mantém o arquivo
  /// original retornado pela câmera para não bloquear o fluxo de autenticação.
  Future<String> _saveToAppStorage(XFile rawFile) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory videosDir = Directory('${appDir.path}/true_pulse_videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = rawFile.path.split('.').last;
      final destinationPath = '${videosDir.path}/liveness_$timestamp.$extension';

      final File savedFile = await File(rawFile.path).copy(destinationPath);
      return savedFile.path;
    } on MissingPluginException {
      return rawFile.path;
    }
  }
}
