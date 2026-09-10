import 'package:flutter/services.dart';

/// Lê o nome do dispositivo configurado no próprio Android
/// (Settings > Sobre o telefone > Nome do dispositivo — o mesmo que
/// aparece ao parear Bluetooth/Wi-Fi Direct) via canal nativo.
class DeviceInfoService {
  static const MethodChannel _channel = MethodChannel('com.camsharelite/device');

  Future<String> getDeviceName() async {
    try {
      final name = await _channel.invokeMethod<String>('getDeviceName');
      return (name == null || name.isEmpty) ? 'Dispositivo Android' : name;
    } catch (_) {
      return 'Dispositivo Android';
    }
  }
}
