import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Servidor HTTP local (LAN) que serve:
/// - `/`        página HTML simples com o stream embutido
/// - `/stream`  stream MJPEG contínuo (multipart/x-mixed-replace)
/// - `/status`  JSON com número de espectadores conectados
class StreamServer {
  HttpServer? _server;
  final Stream<Uint8List> frames;
  int _connectedClients = 0;

  /// Callback opcional para refletir eventos no log visual da UI.
  final void Function(String message, {bool isError})? onEvent;

  StreamServer({required this.frames, this.onEvent});

  int get connectedClients => _connectedClients;
  bool get isRunning => _server != null;

  Future<int> start({int port = 8080}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    onEvent?.call('Servidor HTTP iniciado na porta $port');

    _server!.listen((HttpRequest request) {
      switch (request.uri.path) {
        case '/':
          _serveIndex(request);
          break;
        case '/stream':
          _serveStream(request);
          break;
        case '/status':
          _serveStatus(request);
          break;
        default:
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Não encontrado')
            ..close();
      }
    });

    return _server!.port;
  }

  void _serveIndex(HttpRequest request) {
    request.response.headers.contentType = ContentType.html;
    request.response.write('''
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="utf-8">
  <title>CamShare Lite</title>
  <style>
    body { background:#111; color:#eee; font-family: sans-serif; text-align:center; margin:0; padding:24px; }
    img { max-width:100%; border-radius:8px; }
    h1 { font-size:18px; font-weight:normal; opacity:0.8; }
  </style>
</head>
<body>
  <h1>CamShare Lite — transmissão ao vivo</h1>
  <img src="/stream" alt="stream ao vivo" onerror="setTimeout(()=>location.reload(), 2000)">
</body>
</html>
''');
    request.response.close();
  }

  void _serveStatus(HttpRequest request) {
    request.response.headers.contentType = ContentType.json;
    request.response.write('{"connected_clients": $_connectedClients}');
    request.response.close();
  }

  void _serveStream(HttpRequest request) {
    const boundary = 'frame';
    request.response.headers.set(
      'Content-Type',
      'multipart/x-mixed-replace; boundary=$boundary',
    );
    request.response.headers.set('Cache-Control', 'no-cache');
    request.response.headers.set('Connection', 'close');
    request.response.bufferOutput = false;

    _connectedClients++;
    onEvent?.call('Cliente conectado ($_connectedClients espectador(es))');

    late final StreamSubscription<Uint8List> subscription;
    subscription = frames.listen(
      (jpegBytes) {
        try {
          request.response
            ..write('--$boundary\r\n')
            ..write('Content-Type: image/jpeg\r\n')
            ..write('Content-Length: ${jpegBytes.length}\r\n\r\n');
          request.response.add(jpegBytes);
          request.response.write('\r\n');
        } catch (_) {
          subscription.cancel();
        }
      },
      onError: (_) => subscription.cancel(),
    );

    request.response.done.then((_) {
      subscription.cancel();
      _connectedClients--;
      onEvent?.call('Cliente desconectado ($_connectedClients espectador(es) restante(s))');
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _connectedClients = 0;
    onEvent?.call('Servidor HTTP encerrado');
  }
}
