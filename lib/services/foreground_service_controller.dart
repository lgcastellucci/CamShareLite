import 'package:flutter/services.dart';

/// Controla o Foreground Service nativo (Android) que mantém o app com
/// prioridade de câmera mesmo com a tela apagada/bloqueada ou o usuário
/// trocando de app (ver spec §6.4). O código da câmera e do servidor HTTP
/// continuam rodando normalmente no Dart — este canal só liga/desliga a
/// "casca" nativa que segura o status de foreground junto ao Android.
class ForegroundServiceController {
  static const MethodChannel _channel =
      MethodChannel('com.camsharelite/foreground_service');

  Future<void> start() async {
    try {
      await _channel.invokeMethod('start');
    } catch (_) {
      // Se o canal falhar (ex: rodando em plataforma sem suporte), o app
      // continua funcionando — só perde a garantia de rodar com tela
      // apagada, não trava a experiência principal.
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {
      // idem
    }
  }
}
