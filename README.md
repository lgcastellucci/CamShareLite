# CamShareLite — Código inicial (MVP)

> Nota: o repositório/pasta segue o padrão PascalCase usado nos demais
> projetos (EscolaSync, GDriveMigrator, DiscordArchiver). O `name:` dentro
> do `pubspec.yaml` é `camsharelite` (tudo minúsculo, sem underscore e sem
> PascalCase) — é o formato mais próximo do padrão do repo que o Dart
> permite, já que nomes de pacote só aceitam letras minúsculas, dígitos e
> underscore.

Este pacote contém o código Dart/Flutter do app conforme o spec (`CAMERAWEB_SPEC.md`).
**Não inclui** a pasta `android/` completa (gerada por `flutter create`), pois este
ambiente não tem o Flutter SDK instalado para gerá-la.

## Como integrar

1. Gere o projeto base (se ainda não existir um):
   ```bash
   flutter create --org com.cameraweb --project-name camsharelite .
   ```
   Isso cria `android/`, `ios/`, etc. Ajuste o `applicationId` em
   `android/app/build.gradle` para `com.cameraweb.app` (mesmo já publicado).

2. Copie a pasta `lib/` deste pacote por cima da gerada, e o `pubspec.yaml`.

3. Adicione as permissões de `android_manifest_snippet.xml` ao
   `android/app/src/main/AndroidManifest.xml`.

4. Em `android/app/build.gradle`, garanta:
   ```gradle
   defaultConfig {
       applicationId "com.cameraweb.app"
       minSdkVersion 23
       // manter compileSdk/targetSdk conforme o restante do build
   }
   ```

5. Rode no seu pipeline Docker existente (mesmo do EscolaSync):
   ```bash
   flutter clean && flutter pub get && flutter build appbundle
   ```

## Estrutura

```
lib/
  main.dart                    → entry point, injeta o Provider
  state/app_state.dart         → ChangeNotifier: fases da tela, log, orquestra câmera+servidor
  models/log_entry.dart        → modelo de cada linha do log visual
  services/camera_service.dart → inicializa câmera, converte frames YUV420 → JPEG
  services/stream_server.dart  → HttpServer local: "/", "/stream" (MJPEG), "/status"
  services/network_service.dart→ obtém IP local via Wi-Fi
  screens/home_screen.dart     → UI única com os 5 estados do spec
  widgets/log_view.dart        → lista rolável do log visual
```

## Pontos de atenção conhecidos (MVP)

- **Conversão YUV420 → JPEG** (`camera_service.dart`) é funcional mas não otimizada;
  em aparelhos mais fracos pode valer a pena reduzir ainda mais a resolução
  (`ResolutionPreset.low`) ou aumentar `_processEveryNFrames`.
- **Permissão de localização**: em algumas versões do Android,
  `network_info_plus` exige `ACCESS_FINE_LOCATION` concedida para retornar o IP
  do Wi-Fi — sem isso, `getLocalIp()` pode retornar `null` mesmo conectado.
  Se acontecer, adicionar solicitação dessa permissão junto com a de câmera.
- **Sem HTTPS**: o stream é HTTP puro, aceitável para uso em LAN doméstica
  (conforme decisão do spec — sem autenticação, público na rede local).
- Testado conceitualmente para Android 12 / One UI 4.3 (dispositivo do
  usuário) — validar em execução real antes de assumir como definitivo.

## Não implementado (fora de escopo, conforme spec §7)

- Autenticação/senha, acesso fora da LAN, gravação, detecção de movimento,
  Foreground Service (stream para ao minimizar o app).
