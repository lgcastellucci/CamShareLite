# CamShare Lite (CameraWeb) — Especificação Técnica

## 1. Visão Geral

**Nome de exibição do app: CamShare Lite** (nome de projeto/código interno segue como CameraWeb, package `com.cameraweb.app`).

App Android (Flutter) que:
1. Habilita a câmera do celular.
2. Captura e exibe a imagem em tempo real na tela do app.
3. Ao toque em **"Compartilhar"**, inicia um servidor HTTP local (LAN) que transmite o stream de câmera continuamente.
4. Exibe o link/endereço (`http://<ip-local>:<porta>`) para que outro usuário na mesma rede Wi-Fi acesse o stream pelo navegador.
5. Exibe um **log visual** de cada etapa executada (permissões, câmera iniciada, servidor no ar, cliente conectado, etc.).

**Não há backend em nuvem.** O celular é o próprio servidor. O consumo do stream só funciona enquanto:
- O app estiver aberto e em primeiro plano (ou com serviço em foreground, ver §6.4).
- O celular e o dispositivo espectador estiverem na mesma rede local.

---

## 2. Package Name

```
com.camsharelite.app
```

Definido para a ficha do app no Google Play Console (substitui a intenção inicial de manter `com.cameraweb.app`, herdada do app antigo).

---

## 3. Fluxo de Telas

### 3.1 Tela única (Home) — estados

| Estado | O que exibe |
|---|---|
| **Inicial** | Botão "Habilitar Câmera" + log vazio |
| **Permissão solicitada** | Spinner + log: "Solicitando permissão de câmera..." |
| **Câmera ativa** | Preview ao vivo da câmera + botão "Compartilhar" + log: "Câmera habilitada" |
| **Servidor ativo** | Preview + link exibido (texto selecionável + botão copiar/compartilhar nativo) + botão "Parar Compartilhamento" + log de cada evento |
| **Erro** | Mensagem de erro (permissão negada, sem rede Wi-Fi, porta ocupada) + log correspondente |

### 3.2 Log visual (todas as telas)

Lista rolável, cada linha com timestamp + ícone de status (✅ sucesso / ⚠️ aviso / ❌ erro), por exemplo:

```
[14:32:01] ✅ Permissão de câmera concedida
[14:32:01] ✅ Câmera inicializada (traseira, 1280x720)
[14:32:05] ✅ Servidor HTTP iniciado em 192.168.0.42:8080
[14:32:05] ℹ️  Link pronto para compartilhar
[14:32:20] ✅ Cliente conectado (1 espectador)
```

---

## 4. Arquitetura

```
┌─────────────────────────────┐
│         App Flutter          │
│                               │
│  ┌────────────┐   frames   ┌──────────────┐
│  │  Câmera    │ ─────────▶ │  Servidor    │
│  │ (camera pkg)│           │  HTTP local  │
│  └────────────┘            │ (MJPEG/WS)   │
│         │                  └──────┬───────┘
│         ▼                         │
│   Preview na tela                 │ Wi-Fi/LAN
└────────────────────────────────────┼───────┘
                                      ▼
                        ┌────────────────────────┐
                        │  Navegador de outro     │
                        │  dispositivo na LAN     │
                        │  http://<ip>:<porta>    │
                        └────────────────────────┘
```

### 4.1 Componentes principais

| Componente | Responsabilidade | Sugestão técnica |
|---|---|---|
| Captura de câmera | Obter frames em tempo real | pacote `camera` (Flutter) |
| Servidor HTTP embutido | Servir página HTML + stream de imagens | pacote `dart:io HttpServer` (nativo Dart, sem dependência extra) ou `shelf` |
| Formato de stream | Entregar quadros contínuos ao navegador | **MJPEG** via `multipart/x-mixed-replace` (simples, compatível com `<img src>` sem JS) |
| Descoberta de IP local | Montar o link exibido | pacote `network_info_plus` (obtém IP Wi-Fi do device) |
| Gerenciamento de estado | Controlar estados da tela/log | **Provider** (`ChangeNotifier`) — simples, baixo overhead, adequado a uma tela única com poucos estados |
| Execução em segundo plano | Manter servidor ativo com tela bloqueada/minimizada (opcional, ver §6.4) | Foreground Service Android (`flutter_foreground_task` ou nativo) |

### 4.2 Por que MJPEG e não WebRTC/RTSP

Para uma primeira versão, **MJPEG sobre HTTP** é a opção mais simples:
- Não exige STUN/TURN, sinalização, nem servidor de terceiros.
- O navegador consome direto com uma tag `<img>`, sem player especial.
- Compatível com qualquer navegador moderno na rede local.

Trade-off: maior consumo de banda/CPU que um H.264 real, mas para uso em LAN entre poucos espectadores é aceitável. Uma evolução futura para WebRTC pode ser avaliada depois que o MVP funcionar (ver §8).

---

## 5. Endpoints do Servidor Local

| Rota | Método | Descrição |
|---|---|---|
| `/` | GET | Página HTML simples com `<img src="/stream">` e auto-reload em caso de queda de conexão |
| `/stream` | GET | Stream MJPEG contínuo (`Content-Type: multipart/x-mixed-replace; boundary=frame`) |
| `/status` | GET | (opcional) JSON com status do servidor, nº de espectadores conectados — útil para o log visual |

---

## 6. Requisitos Técnicos

### 6.1 Permissões (Android Manifest)
- `CAMERA`
- `INTERNET` (para o `HttpServer` — tecnicamente necessária mesmo sendo só LAN)
- `ACCESS_WIFI_STATE` / `ACCESS_NETWORK_STATE` (para obter IP local)
- `ACCESS_FINE_LOCATION` — **atenção:** em algumas versões do Android é exigida para ler o SSID/IP do Wi-Fi

### 6.2 Compatibilidade
- `minSdkVersion`: **23 (Android 6.0)** — mesmo padrão usado no EscolaSync, compatível com o toolchain atual (AGP 8.11+, compileSdk 36).
- Dispositivo de teste do usuário: Android 12 (One UI 4.3, Samsung).

### 6.3 Rede
- Funciona apenas quando o celular está conectado a uma rede Wi-Fi (não funciona em dados móveis puros, pois não há IP de LAN acessível a terceiros).
- Tratar caso "sem Wi-Fi" com mensagem clara no log (❌ "Conecte-se a uma rede Wi-Fi para compartilhar").

### 6.4 Continuidade em segundo plano

**Decisão atualizada: Opção B — Foreground Service real.** O app usa um
Foreground Service Android (`foregroundServiceType="camera"`) que mantém o
processo com prioridade elevada mesmo com a tela apagada/bloqueada ou o
usuário trocando de app. Uma notificação persistente é obrigatória
enquanto o compartilhamento estiver ativo (exigência do próprio Android
para apps que usam câmera em segundo plano) — o usuário vê "CamShareLite
está transmitindo ao vivo" na barra de notificações, com botão de parar.

Trade-offs assumidos conscientemente: mais consumo de bateria (câmera
continua processando frames o tempo todo) e a notificação persistente é
obrigatória, não opcional (não dá pra rodar em background sem ela, é
restrição do Android, não escolha de design).

Superada a decisão anterior ("Opção A — só primeiro plano, sem Foreground
Service").

### 6.5 Encerramento
- Botão "Parar Compartilhamento" deve: parar o servidor HTTP, liberar a câmera (ou mantê-la só em preview), registrar no log.
- Ao fechar o app, encerrar servidor e liberar recursos de câmera corretamente (evitar vazamento de recursos nativos).

---

## 7. Fora de Escopo (nesta versão)
- Autenticação/senha para acessar o stream — **decisão de design, não pendência**: o app é intencionalmente público/aberto na LAN, sem conta e sem pareamento (ver §7.1).
- Acesso fora da rede local (internet/NAT traversal).
- Gravação/armazenamento do vídeo.
- Detecção de movimento, alertas, walkie-talkie e demais recursos "smart" de apps tipo Alfred Camera.
- Múltiplas câmeras simultâneas ou troca frontal/traseira durante o stream (pode ser adicionado depois).

### 7.1 Diferença em relação ao Alfred Camera (referência do usuário)

O Alfred Camera foi citado como inspiração, mas o objetivo aqui é o oposto em complexidade:

| | Alfred Camera | CameraWeb |
|---|---|---|
| Pareamento | Conta de usuário + QR code entre 2 apps | Nenhum — só abrir o link |
| Transporte | Relay via nuvem (funciona por WiFi ou dados móveis, de qualquer lugar) | Direto na LAN, sem servidor externo |
| Visualização | App dedicado no dispositivo espectador | Qualquer navegador comum |
| Recursos extras | Detecção de movimento, alertas, gravação em nuvem, walkie-talkie | Nenhum — só o stream ao vivo |
| Acesso | Restrito à conta/"Trust Circle" | Público — quem tiver o link na mesma rede acessa |

Essa simplicidade é a escolha deliberada do projeto: sem conta, sem nuvem, sem IA — só câmera → stream → link.

---

## 8. Possíveis Evoluções Futuras
- Proteção por senha/token na URL do stream.
- Alternar câmera frontal/traseira em tempo real.
- Opção de acesso remoto (fora da LAN) via túnel (ngrok-like) ou backend próprio.
- Migrar de MJPEG para WebRTC para menor latência/consumo.

---

## 9. Decisões Finais Confirmadas
Todas as pendências foram resolvidas — spec pronto para codificação.
