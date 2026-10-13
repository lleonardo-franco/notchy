<p align="center">
  <img src="docs/icon.png" width="128" alt="Ícone do Notchy">
</p>

<h1 align="center">Notchy</h1>

<p align="center">Seu notch, menos inútil. Música, Claude Code, agenda, vídeo e notificações no notch do MacBook.</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-orange" alt="Swift e SwiftUI">
  <img src="https://img.shields.io/badge/versão-1.0.0-d97757" alt="Versão 1.0.0">
</p>

---

O Notchy transforma o notch do MacBook numa pequena central. Recolhido, ele mostra só o que importa nas laterais do notch: a capa da música, o status do Claude, a contagem para a próxima reunião, notificações. Passando o mouse, ele abre com o player, abas e controles.

## O que tem

### Música
- Spotify e Apple Music: capa, título, artista, play/pause, anterior/próxima
- Barra de progresso arrastável para pular trechos
- Fundo do notch tingido com a cor da capa

### YouTube no notch
- Com um vídeo aberto no Safari, Chrome, Brave, Edge ou Chromium, aparece **Assistir no notch**
- A aba pausa e o vídeo continua do mesmo segundo num mini player embaixo do notch, visível enquanto você navega
- Avançar e voltar 10 s, tamanho pequeno ou grande, voltar para a aba no mesmo ponto

### Claude Code
- Status de cada sessão: trabalhando, esperando você, terminou
- **Aprovar pelo notch**: quando o Claude pede permissão, aparecem Permitir, Negar e Responder no terminal
- Clique numa sessão para ir até a aba certa do Terminal ou do iTerm
- Cota de 5 horas e de 7 dias, com aviso em 80% e 95%
- Tempo da tarefa em andamento no notch recolhido

### Agenda e reuniões
- Próximos compromissos do Calendário com botão **Entrar** para Zoom, Meet, Teams e Webex
- Contagem regressiva no notch recolhido e aviso antes da reunião

### E mais
- **Clima**: temperatura ao lado do relógio e previsão das próximas horas (Open-Meteo)
- **Copiados**: histórico dos últimos 30 itens copiados, só na memória
- **Notificações**: contador animado do WhatsApp e do ClickUp
- **Bluetooth**: bateria dos fones (AirPods com esquerdo, direito e estojo) e aviso de bateria baixa
- **Gestos**: dois dedos para os lados trocam de música, para cima e para baixo mudam o volume
- **Vibração no trackpad** com intensidade configurável e uma área para testar
- **Animação ao desligar**, no estilo de TV antiga

## Instalação

Precisa de macOS 14 ou mais novo, das ferramentas de linha de comando do Xcode (`xcode-select --install`) e de Python 3, que vem com elas.

```bash
git clone https://github.com/lleonardo-franco/notchy.git ~/Projects/notchy
cd ~/Projects/notchy
./install.sh
```

O instalador compila o app, instala em `/Applications`, conecta os hooks do Claude Code e instala o comando `notchy`. Na primeira vez ele:

1. cria um certificado local, **Notchy Local Signing**, e pede a senha do Mac uma vez para confiar nele e liberar o `codesign`;
2. abre a janela de boas-vindas, onde você libera só as permissões que for usar.

Como o app é sempre assinado com o mesmo certificado, as permissões ficam salvas entre as versões. Nas atualizações seguintes o instalador só refaz o que mudou.

## Comando `notchy`

```bash
notchy              # abre
notchy stop         # fecha
notchy restart      # reinicia
notchy settings     # ajustes
notchy welcome      # boas-vindas e permissões
notchy city "Farroupilha"   # cidade do clima (notchy city auto volta ao automático)
notchy doctor       # diagnóstico de assinatura, certificado e permissões
notchy update       # baixa a versão mais nova do GitHub e instala
notchy uninstall    # remove tudo
```

## Permissões

| Permissão | Para quê |
|---|---|
| Acessibilidade | Ler o número de notificações do WhatsApp e do ClickUp no Dock |
| Automação (Safari, Chrome) | Ver vídeos do YouTube abertos, pausar a aba e voltar no mesmo ponto |
| Automação (Spotify, Music) | Mostrar e controlar a música |
| Automação (Terminal, iTerm) | Ir até a sessão certa do Claude Code |
| Calendário | Próximas reuniões |
| Bluetooth | Bateria dos dispositivos |

Para o vídeo continuar do mesmo segundo, ative **Permitir JavaScript de Eventos Apple** no menu Desenvolvedor do navegador. No Safari, mostre esse menu em Ajustes → Avançado → Mostrar recursos para desenvolvedores da Web.

## Como funciona

| Parte | Como |
|---|---|
| Janela | `NSPanel` acima da barra de menus, posicionado pelo `safeAreaInsets` da tela com notch |
| Música | Notificações distribuídas do Spotify e do Music + AppleScript |
| Claude Code | Hooks gravam o estado de cada sessão em `~/.notchy/sessions`; o hook `PermissionRequest` espera a resposta do notch; a status line fornece a cota |
| Vídeo | AppleScript lê as abas do navegador; o player usa a API de iframe do YouTube num `WKWebView` |
| Notificações | Número do ícone no Dock, lido pela API de Acessibilidade |
| Bluetooth | `system_profiler SPBluetoothDataType` |
| Vibração | Motor do trackpad direto, para funcionar mesmo com o app em segundo plano |
| Tela cheia | Detecta Spaces de tela cheia para esconder o notch |

O app pausa as verificações periódicas quando a tela bloqueia ou o Mac dorme, e diminui o ritmo com o notch fechado.

## Desenvolvimento

```bash
swift build             # compila
./build.sh              # gera build/Notchy.app
./install.sh --force    # reinstala tudo do zero
```

Antes de publicar uma versão, siga o [roteiro de teste](TESTING.md). As mudanças de cada versão estão no [CHANGELOG](CHANGELOG.md).

## Licença

[MIT](LICENSE) © Leonardo Franco Lima
