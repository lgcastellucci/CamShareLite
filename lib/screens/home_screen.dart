import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/log_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Dispara assim que a tela abre: se a permissão já existe, pula direto
    // pra câmera ativa + compartilhamento, sem precisar de toque nenhum.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('CamShareLite')),
      body: Column(
        children: [
          Expanded(flex: 3, child: _buildMainArea(context, state)),
          const Divider(height: 1),
          Expanded(flex: 2, child: LogView(logs: state.logs)),
        ],
      ),
    );
  }

  Widget _buildMainArea(BuildContext context, AppState state) {
    switch (state.phase) {
      case AppPhase.initial:
        return _centered(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Habilitar Câmera'),
            onPressed: () => context.read<AppState>().requestCameraAndInitialize(),
          ),
        );

      case AppPhase.requestingPermission:
        return const Center(child: CircularProgressIndicator());

      case AppPhase.cameraReady:
        return Column(
          children: [
            Expanded(child: _cameraPreview(state)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Compartilhar'),
                onPressed: () => context.read<AppState>().startSharing(),
              ),
            ),
          ],
        );

      case AppPhase.serverRunning:
        return Column(
          children: [
            Expanded(child: _cameraPreview(state)),
            _shareLinkPanel(context, state),
          ],
        );

      case AppPhase.error:
        return _centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.read<AppState>().requestCameraAndInitialize(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        );
    }
  }

  Widget _cameraPreview(AppState state) {
    final controller = state.cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    // O sensor da câmera reporta o tamanho sempre em orientação paisagem,
    // então invertemos largura/altura para calcular o aspect ratio correto
    // em retrato. Usamos FittedBox + BoxFit.cover para preencher todo o
    // espaço disponível cortando as bordas, em vez de deixar tarjas pretas
    // (comportamento padrão do CameraPreview, que respeita o aspect ratio
    // nativo e "sobra" espaço preto).
    final previewSize = controller.value.previewSize;
    final previewW = previewSize?.height ?? 1.0;
    final previewH = previewSize?.width ?? 1.0;

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewW,
            height: previewH,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _shareLinkPanel(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  state.shareUrl ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text('${state.connectedClients} 👁'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '📷 ${state.deviceName}',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.stop_circle),
            label: const Text('Parar Compartilhamento'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => context.read<AppState>().stopSharing(),
          ),
        ],
      ),
    );
  }

  Widget _centered({required Widget child}) => Center(child: child);
}
