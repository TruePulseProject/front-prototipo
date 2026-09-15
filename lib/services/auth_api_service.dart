import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class AuthenticationApiException implements Exception {
  final String message;

  const AuthenticationApiException(this.message);

  @override
  String toString() => message;
}

class VerificationResult {
  final String status;
  final bool? isDeepfake;
  final bool? isCorrectPerson;
  final double? confidence;
  final String? message;

  const VerificationResult({
    required this.status,
    this.isDeepfake,
    this.isCorrectPerson,
    this.confidence,
    this.message,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      status: json['status'] as String? ?? 'error',
      isDeepfake: json['is_deepfake'] as bool?,
      isCorrectPerson: json['is_correct_person'] as bool?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      message: json['message'] as String?,
    );
  }
}

class AuthApiService {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _defaultBaseUrl = 'http://localhost:8000';
  static const _requestTimeout = Duration(seconds: 30);
  static const _pollInterval = Duration(seconds: 1);
  static const _pollTimeout = Duration(minutes: 2);

  final http.Client _client;
  final String baseUrl;

  AuthApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? _resolveBaseUrl()).replaceFirst(RegExp(r'/$'), '');

  static String _resolveBaseUrl() {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return _defaultBaseUrl;
  }

  Future<VerificationResult> authenticate(XFile video) async {
    final jobId = await _uploadVideo(video);
    final deadline = DateTime.now().add(_pollTimeout);

    while (DateTime.now().isBefore(deadline)) {
      final result = await _getResult(jobId);
      if (result.status != 'processing') return result;
      await Future<void>.delayed(_pollInterval);
    }

    throw const AuthenticationApiException(
      'A API demorou mais que o esperado para processar o vídeo.',
    );
  }

  Future<String> _uploadVideo(XFile video) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/auth/login'),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'video',
        await video.readAsBytes().timeout(_requestTimeout),
        filename: video.name.isEmpty ? 'liveness.mp4' : video.name,
        contentType: _contentTypeFor(video.name),
      ),
    );

    final streamedResponse = await _client
        .send(request)
        .timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthenticationApiException(_errorMessage(data, response));
    }

    final jobId = data['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const AuthenticationApiException(
        'A API não retornou um identificador para a verificação.',
      );
    }
    return jobId;
  }

  MediaType _contentTypeFor(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'webm':
        return MediaType('video', 'webm');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'mkv':
        return MediaType('video', 'x-matroska');
      case 'mp4':
      default:
        return MediaType('video', 'mp4');
    }
  }

  Future<VerificationResult> _getResult(String jobId) async {
    final response = await _client
        .get(Uri.parse('$baseUrl/auth/result/$jobId'))
        .timeout(_requestTimeout);
    final data = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthenticationApiException(_errorMessage(data, response));
    }
    return VerificationResult.fromJson(data);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // The status code below is included in the user-facing error.
    }
    return <String, dynamic>{};
  }

  String _errorMessage(Map<String, dynamic> data, http.Response response) {
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    return 'A API respondeu com o status ${response.statusCode}.';
  }

  void dispose() => _client.close();
}
