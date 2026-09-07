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
  final String deviceName;
  int _connectedClients = 0;

  /// Callback opcional para refletir eventos no log visual da UI.
  final void Function(String message, {bool isError})? onEvent;

  StreamServer({required this.frames, this.onEvent, this.deviceName = 'Dispositivo Android'});

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
    final safeName = deviceName.replaceAll('<', '').replaceAll('>', '');
    request.response.write('''
<!DOCTYPE html>
<html lang="pt-br">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <title>$safeName — CamShareLite</title>
  <style>
    html, body {
      height: 100%;
      margin: 0;
      background: #111;
    }
    body {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
    }
    img {
      width: 100vw;
      height: 100vh;
      object-fit: cover;
      display: block;
    }
    .device-label {
      position: fixed;
      top: 12px;
      left: 12px;
      color: #fff;
      background: rgba(0,0,0,0.5);
      padding: 6px 12px;
      border-radius: 999px;
      font-family: sans-serif;
      font-size: 14px;
      z-index: 10;
    }
  </style>
</head>
<body>
  <div class="device-label">📷 $safeName</div>
  <img src="/stream" alt="stream ao vivo" onerror="setTimeout(()=>location.reload(), 2000)">
</body>
</html>
''');
    request.response.close();
  }

  void _serveStatus(HttpRequest request) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      '{"connected_clients": $_connectedClients, "device_name": "${deviceName.replaceAll('"', '')}"}',
    );
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
