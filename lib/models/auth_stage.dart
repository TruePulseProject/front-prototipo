/// Representa os estágios do fluxo de autenticação por prova de vida.
enum AuthStage {
  /// Aguardando o usuário iniciar a captura.
  idle,

  /// Gravando o vídeo de 5 segundos utilizado na prova de vida.
  scanning,

  /// Vídeo capturado, validando os sinais biológicos (ex.: envio à API).
  analyzing,
}
