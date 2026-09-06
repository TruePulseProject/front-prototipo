import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'screens/face_auth_page.dart';

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
