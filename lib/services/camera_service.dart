import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Encapsula a câmera e expõe um stream contínuo de frames já
/// codificados em JPEG, prontos para serem servidos via HTTP (MJPEG).
class CameraService {
  CameraController? _controller;
  final _frameController = StreamController<Uint8List>.broadcast();
  bool _isStreaming = false;
  int _frameSkipCounter = 0;

  /// Pula frames para não sobrecarregar CPU/banda — processa 1 a cada N.
  static const int _processEveryNFrames = 3;

  Stream<Uint8List> get frames => _frameController.stream;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  CameraController? get controller => _controller;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', 'Nenhuma câmera encontrada no dispositivo.');
    }

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
  }

  void startFrameCapture() {
    if (_controller == null || _isStreaming) return;
    _isStreaming = true;
    _controller!.startImageStream(_onFrameAvailable);
  }

  Future<void> stopFrameCapture() async {
    if (_controller != null && _isStreaming) {
      await _controller!.stopImageStream();
    }
    _isStreaming = false;
  }

  void _onFrameAvailable(CameraImage image) {
    // Processa só 1 a cada N frames para reduzir carga de CPU.
    _frameSkipCounter++;
    if (_frameSkipCounter % _processEveryNFrames != 0) return;

    try {
      final jpeg = _convertYUV420toJpeg(image);
      if (!_frameController.isClosed) {
        _frameController.add(jpeg);
      }
    } catch (_) {
      // Frame corrompido/incompleto — descarta e segue para o próximo.
    }
  }

  /// Converte um frame YUV420 (formato nativo da câmera Android) para JPEG.
  /// Conversão simplificada, suficiente para preview/stream em baixa/média
  /// resolução; não é otimizada para alta taxa de quadros.
  Uint8List _convertYUV420toJpeg(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final rgbImage = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      final yRowOffset = y * yRowStride;
      final uvRowOffset = (y >> 1) * uvRowStride;

      for (int x = 0; x < width; x++) {
        final yIndex = yRowOffset + x;
        final uvIndex = uvRowOffset + (x >> 1) * uvPixelStride;

        final yValue = yBuffer[yIndex];
        final uValue = uBuffer[uvIndex];
        final vValue = vBuffer[uvIndex];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }

    return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 70));
  }

  Future<void> dispose() async {
    await stopFrameCapture();
    await _controller?.dispose();
    await _frameController.close();
  }
}
