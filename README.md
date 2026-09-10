# CamShareLite — Código inicial (MVP)

> Nota: o repositório/pasta segue o padrão PascalCase usado nos demais
> projetos (EscolaSync, GDriveMigrator, DiscordArchiver). O `name:` dentro
> do `pubspec.yaml` é `camsharelite` (tudo minúsculo, sem underscore e sem
> PascalCase) — é o formato mais próximo do padrão do repo que o Dart
> permite, já que nomes de pacote só aceitam letras minúsculas, dígitos e
> underscore.

Este pacote contém o código Dart/Flutter do app conforme o spec (`CAMERAWEB_SPEC.md`).

## Estado atual do projeto

O projeto Android real já existe (gerado via `flutter create`, usando
Kotlin DSL) e já passou por builds no container `BuildCamShareLite`. As
correções vigentes estão em `android_config/` — use o script
`apply_android_config.sh` (ver seção abaixo) pra aplicar tudo de uma vez,
em vez de copiar arquivo por arquivo na mão.

`applicationId` atual: **`com.camsharelite.app`**.

## Como aplicar (`apply_android_config.sh`)

```bash
./apply_android_config.sh /caminho/para/o/projeto/real
```

Rode de qualquer lugar (o script se localiza sozinho), passando o caminho
da raiz do projeto Flutter real — a pasta que contém `android/`, `lib/`,
`pubspec.yaml`. Se você já estiver dentro dela, pode chamar sem argumento.

O script:
- Copia `gradle.properties`, `app_build.gradle.kts`, `AndroidManifest.xml`
  e `MainActivity.kt` de `android_config/` para os caminhos certos dentro
  de `android/`.
- Copia os ícones de `store_assets/android_res/` para
  `android/app/src/main/res/`.
- Sobrescreve direto, sem backup — rode com o projeto já versionado/commitado
  se quiser poder reverter.

Depois de rodar, dentro do container: `./gradlew --stop` (se já tiver um
daemon de antes) e `./build.sh` normalmente.

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

## Assets para a Play Store (`store_assets/`)

Gerados programaticamente (design simples: câmera + ondas de transmissão, tema teal do app). **Screenshots reais não estão incluídos** — a Play Store exige capturas da tela rodando de verdade; gere-as depois que o app estiver buildado e rodando no aparelho/emulador.

```
store_assets/
  play_store/
    icon_512.png                    → Play Console → Presença na loja → Ícone do app (512×512)
    feature_graphic_1024x500.png    → Play Console → Presença na loja → Gráfico de destaque
  android_res/
    mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/
      ic_launcher.png               → ícone legado (launchers sem suporte a adaptive icon)
      ic_launcher_foreground.png    → camada de primeiro plano do ícone adaptativo
    mipmap-anydpi-v26/
      ic_launcher.xml               → referencia background (cor) + foreground
    values/
      ic_launcher_background.xml    → cor de fundo do ícone adaptativo (#00897B)
```

Para aplicar no projeto: copie o conteúdo de `android_res/` por cima de
`android/app/src/main/res/` (mesclando as pastas `mipmap-*` e `values/`
existentes, geradas pelo `flutter create`).

## Configuração do Gradle (`android_config/`)

> Aplicado automaticamente pelo `apply_android_config.sh` — a lista abaixo é só
> a explicação de cada arquivo, não é mais um passo manual obrigatório.

**Atenção: seu projeto usa Kotlin DSL** (`build.gradle.kts`, `settings.gradle.kts`) — os arquivos abaixo já estão no formato certo.

- **`android_config/gradle.properties`** → substitui `android/gradle.properties`
  (o original ainda estava com `-Xmx8G`, causa do `daemon disappeared`).
  Preserva as flags `android.newDsl` / `android.builtInKotlin` que o
  template do Flutter já tinha adicionado.

- **`android_config/app_build.gradle.kts`** → substitui
  `android/app/build.gradle.kts`. Corrige três coisas que estavam erradas:
  - `applicationId` estava `com.cameraweb.camsharelite` (efeito colateral
    do `flutter create --org com.cameraweb --project-name camsharelite`) —
    agora **`com.camsharelite.app`**, o valor exigido pela ficha do app no
    Play Console (já passou por `com.cameraweb.app` e `app.camsharelite.com`
    antes de chegar nesse — o Play Console é quem manda, ele acusa o erro
    exato quando o pacote enviado não bate com o cadastrado na ficha).
    O `namespace` continua `com.cameraweb.camsharelite` de propósito, pois
    é o pacote real da pasta
    `kotlin/com/cameraweb/camsharelite/MainActivity.kt` — não precisa (e
    não deve) bater com o `applicationId`.
  - `minSdk` estava usando o padrão do Flutter — agora fixo em `23`.
  - `buildTypes.release.signingConfig` estava `signingConfigs.getByName("debug")`
    (padrão do template) — agora aponta para o `signingConfigs.release`
    recém-criado, lendo `STORE_FILE`/`KEY_ALIAS`/`STORE_PASSWORD`/`KEY_PASSWORD`
    das env vars do container.

- **`android_config/AndroidManifest.xml`** → substitui
  `android/app/src/main/AndroidManifest.xml`. É o manifest original do seu
  projeto com as permissões do spec (câmera, Wi-Fi, internet, localização)
  já mescladas no topo.

- **`android_config/MainActivity.kt`** → substitui
  `android/app/src/main/kotlin/com/cameraweb/camsharelite/MainActivity.kt`.
  Tem dois `MethodChannel`s agora: `com.camsharelite/device` (nome do
  dispositivo, já existia) e **`com.camsharelite/foreground_service`**
  (novo — inicia/para o Foreground Service abaixo). Também ativa exibição
  de ponta a ponta no `onCreate` via `WindowCompat.setDecorFitsSystemWindows`
  (aviso do Play Console sobre Android 15+/targetSdk 35 — não dá pra usar
  `enableEdgeToEdge()` direto porque `FlutterActivity` estende `Activity`
  puro, não `ComponentActivity`; exige a dependência `androidx.core:core-ktx`,
  já incluída no `app_build.gradle.kts`).

- **`android_config/StreamForegroundService.kt`** (novo) → vai em
  `android/app/src/main/kotlin/com/cameraweb/camsharelite/StreamForegroundService.kt`.
  Foreground Service "casca" (`foregroundServiceType="camera"`) que
  mantém o processo com prioridade elevada enquanto o compartilhamento
  está ativo — sem ele, o Android tende a suspender o acesso à câmera
  quando a tela apaga ou o app vai pra segundo plano (ver §6.4 do spec,
  decisão atualizada). Mostra uma notificação persistente obrigatória
  ("CamShareLite está transmitindo ao vivo") com botão de parar. A câmera
  e o servidor HTTP continuam rodando no código Dart normal — este
  Service só segura o status de foreground junto ao sistema.

## Foreground Service — o que mudou (spec §6.4)

Decisão anterior era "só primeiro plano, sem Foreground Service". Isso
mudou: agora o app usa um Foreground Service de verdade pra continuar
rodando com a tela apagada/bloqueada. Implicações:

- **Notificação persistente é obrigatória** enquanto compartilhando —
  não dá pra tirar, é exigência do próprio Android pra apps que usam
  câmera em segundo plano, não escolha de design.
- **Novas permissões** no Manifest: `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_CAMERA` (Android 14+), `POST_NOTIFICATIONS`
  (Android 13+ — pedida em tempo de execução, junto com a de câmera).
  Se o usuário negar a de notificação, o app avisa no log mas continua
  funcionando (só perde a garantia de rodar com tela apagada).
- **Mais consumo de bateria** — a câmera continua processando frames o
  tempo todo, não só quando a tela está visível.

## Screenshots para a Play Store (`store_assets/play_store/screenshots/`)

4 capturas **reais** do app rodando (não são mockups), cortadas para caber
no limite de proporção 2:1 que a Play Store exige (as originais eram
1080×2400/2340, cortadas para 1080×2160):

1. `01_tela_inicial.jpg` — tela "Habilitar Câmera"
2. `02_camera_pronta.jpg` — preview ativo, botão "Compartilhar"
3. `03_compartilhando.jpg` — servidor rodando, link exibido
4. `04_visao_navegador.jpg` — o que o espectador vê no navegador

⚠️ São da versão 1.0.0, **antes** do ajuste de tela cheia e do nome do
dispositivo. Servem para publicar agora, mas vale recapturar depois que a
1.0.1 estiver rodando — vai ficar bem mais limpo sem o espaço preto.

## Não implementado (fora de escopo, conforme spec §7)

- Autenticação/senha, acesso fora da LAN, gravação, detecção de movimento,
  Foreground Service (stream para ao minimizar o app).
