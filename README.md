# true_pulse_front

Aplicativo Flutter de captura de prova de vida integrado à API FastAPI em
`../api-prototipo`.

## Executando com a API

1. Inicie a API na porta 8000:

   ```bash
   cd ../api-prototipo
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

2. Execute o Flutter informando a URL acessível pelo dispositivo:

   ```bash
   flutter run --dart-define=API_BASE_URL=http://localhost:8000
   ```

   No emulador Android, o cliente usa `http://10.0.2.2:8000` por padrão.
   Para um dispositivo físico, substitua `localhost` pelo IP da máquina na
   rede local, por exemplo:

   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
   ```

Após a captura, o front envia o vídeo como `multipart/form-data` para
`POST /auth/login` e consulta `GET /auth/result/{job_id}` a cada segundo até
o processamento terminar. Os estados `approved`, `rejected` e `error` são
refletidos no diálogo final.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
