import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/log_entry.dart';
import '../services/camera_service.dart';
import '../services/device_info_service.dart';
import '../services/foreground_service_controller.dart';
import '../services/network_service.dart';
import '../services/stream_server.dart';

enum AppPhase {
  initial,
  requestingPermission,
  cameraReady,
  serverRunning,
  error,
}

/// Estado central do app — controla a fase da tela, o log visual,
/// e orquestra câmera + servidor HTTP local.
class AppState extends ChangeNotifier {
  final CameraService _cameraService = CameraService();
  final NetworkService _networkService = NetworkService();
  final DeviceInfoService _deviceInfoService = DeviceInfoService();
  final ForegroundServiceController _foregroundService = ForegroundServiceController();
  StreamServer? _streamServer;

  AppPhase _phase = AppPhase.initial;
  final List<LogEntry> _logs = [];
  String? _shareUrl;
  int _connectedClients = 0;
  String _deviceName = 'Dispositivo Android';

  AppPhase get phase => _phase;
  List<LogEntry> get logs => List.unmodifiable(_logs);
  String? get shareUrl => _shareUrl;
  int get connectedClients => _connectedClients;
  String get deviceName => _deviceName;
  CameraService get cameraService => _cameraService;

  void _log(String message, {LogLevel level = LogLevel.info}) {
    _logs.add(LogEntry(message: message, level: level));
    notifyListeners();
  }

  void _setPhase(AppPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  /// Chamado uma vez, ao abrir o app: se a permissão de câmera já foi
  /// concedida antes, entra direto ativando a câmera e já inicia o
  /// compartilhamento automaticamente — sem precisar tocar em nenhum botão.
  /// Se a permissão ainda não foi concedida, dispara o pedido normalmente
  /// (o diálogo do sistema aparece do mesmo jeito).
  Future<void> bootstrap() async {
    await requestCameraAndInitialize();
    if (_phase == AppPhase.cameraReady) {
      await startSharing();
    }
  }

  /// Passo 1: solicita permissão de câmera e inicializa o preview.
  Future<void> requestCameraAndInitialize() async {
    _setPhase(AppPhase.requestingPermission);
    _log('Solicitando permissão de câmera...');

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _log('Permissão de câmera negada', level: LogLevel.error);
      _setPhase(AppPhase.error);
      return;
    }
    _log('Permissão de câmera concedida', level: LogLevel.success);

    _deviceName = await _deviceInfoService.getDeviceName();
    _log('Dispositivo identificado: $_deviceName', level: LogLevel.info);

    try {
      await _cameraService.initialize();
      _log('Câmera inicializada', level: LogLevel.success);
      _setPhase(AppPhase.cameraReady);
    } catch (e) {
      _log('Falha ao inicializar câmera: $e', level: LogLevel.error);
      _setPhase(AppPhase.error);
    }
  }

  /// Passo 2: inicia captura contínua + servidor HTTP local.
  Future<void> startSharing({int port = 8080}) async {
    // Verifica Wi-Fi antes de tentar subir o servidor.
    final ip = await _networkService.getLocalIp();
    if (ip == null) {
      _log('Conecte-se a uma rede Wi-Fi para compartilhar', level: LogLevel.error);
      _setPhase(AppPhase.error);
      return;
    }

    // Notificação é obrigatória pro Foreground Service ficar visível
    // (Android 13+ exige permissão em tempo de execução pra isso). Se
    // negada, o Service ainda tenta rodar, mas sem garantia de manter
    // prioridade — por isso só logamos um aviso, não bloqueamos o fluxo.
    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      _log(
        'Permissão de notificação negada — o app pode não continuar rodando com a tela apagada',
        level: LogLevel.warning,
      );
    }

    _cameraService.startFrameCapture();
    await _foregroundService.start();
    _log('Serviço em primeiro plano ativado (mantém rodando com tela apagada)', level: LogLevel.success);

    _streamServer = StreamServer(
      frames: _cameraService.frames,
      deviceName: _deviceName,
      onEvent: (message, {isError = false}) {
        _log(message, level: isError ? LogLevel.error : LogLevel.success);
        _connectedClients = _streamServer?.connectedClients ?? 0;
        notifyListeners();
      },
    );

    try {
      final boundPort = await _streamServer!.start(port: port);
      _shareUrl = 'http://$ip:$boundPort';
      _log('Link pronto para compartilhar: $_shareUrl', level: LogLevel.info);
      _setPhase(AppPhase.serverRunning);
    } catch (e) {
      _log('Falha ao iniciar servidor: $e', level: LogLevel.error);
      _setPhase(AppPhase.error);
    }
  }

  /// Passo 3: para o compartilhamento, mas mantém o preview da câmera.
  Future<void> stopSharing() async {
    await _streamServer?.stop();
    await _cameraService.stopFrameCapture();
    await _foregroundService.stop();
    _shareUrl = null;
    _connectedClients = 0;
    _log('Compartilhamento encerrado', level: LogLevel.info);
    _setPhase(AppPhase.cameraReady);
  }

  Future<void> disposeAll() async {
    await _streamServer?.stop();
    await _foregroundService.stop();
    await _cameraService.dispose();
  }
}
