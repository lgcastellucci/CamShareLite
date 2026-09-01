import 'package:network_info_plus/network_info_plus.dart';

/// Responsável por obter o IP local (Wi-Fi) do dispositivo,
/// usado para montar o link exibido ao usuário.
class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Retorna o IP local (ex: 192.168.0.42) ou null se não houver
  /// conexão Wi-Fi ativa / permissão negada.
  Future<String?> getLocalIp() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      return ip;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getWifiName() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (_) {
      return null;
    }
  }
}
