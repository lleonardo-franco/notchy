<div align="center">

<img src="docs/icon.png" width="112" alt="Ícone do Notchy">

# Notchy

**O notch do seu MacBook, finalmente útil.**<br>
Música, Claude Code, agenda, YouTube e notificações bem onde fica a câmera.

[![Release](https://img.shields.io/github/v/release/lleonardo-franco/notchy?color=d97757&label=versão)](https://github.com/lleonardo-franco/notchy/releases)
[![Build](https://github.com/lleonardo-franco/notchy/actions/workflows/build.yml/badge.svg)](https://github.com/lleonardo-franco/notchy/actions/workflows/build.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111?logo=apple)](#requisitos)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](Package.swift)
[![Licença: MIT](https://img.shields.io/badge/licença-MIT-3b82f6)](LICENSE)
[![PRs bem-vindos](https://img.shields.io/badge/PRs-bem--vindos-22c55e)](CONTRIBUTING.pt-BR.md)

[English](README.md) · **Português** · [Español](README.es.md)

<br>

<img src="docs/hero.svg" width="100%" alt="Notchy aberto embaixo do notch do MacBook, mostrando a música tocando, sessões do Claude Code e abas">

</div>

---

O Notchy transforma o notch numa pequena central. Recolhido, ele mostra só o que importa dos lados da câmera: a capa da música, o status do Claude Code, a contagem para a próxima reunião, notificações. Passe o mouse e ele abre com o player, abas e controles. Feche e ele desliga como uma TV antiga.

## Sumário

- [Funcionalidades](#funcionalidades)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Uso](#uso)
- [Permissões](#permissões)
- [Como funciona](#como-funciona)
- [Perguntas frequentes](#perguntas-frequentes)
- [Roadmap](#roadmap)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

## Funcionalidades

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎵 Música</h3>
      Spotify e Apple Music com capa, título e controles. Arraste a barra de progresso para pular trechos. O notch ganha um tom da cor da capa.
    </td>
    <td width="50%" valign="top">
      <h3>🤖 Claude Code</h3>
      Status de cada sessão em tempo real. <b>Aprove ou negue pedidos de permissão pelo notch</b>, pule para a aba certa do Terminal ou do iTerm e acompanhe a cota de 5 horas e de 7 dias.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>▶️ YouTube no notch</h3>
      Tem um vídeo tocando no Safari, Chrome, Brave, Edge ou Chromium? Mande para um mini player embaixo do notch. Ele continua do mesmo segundo e na mesma velocidade, e devolve para a aba quando você terminar.
    </td>
    <td valign="top">
      <h3>📅 Agenda</h3>
      Próximos compromissos com botão <b>Entrar</b> para Zoom, Meet, Teams e Webex, e contagem regressiva no notch recolhido antes de cada reunião.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>🔔 Notificações</h3>
      Contadores animados do WhatsApp, Slack, Telegram, Discord e ClickUp, com o ícone de cada app.
    </td>
    <td valign="top">
      <h3>🎧 Bluetooth</h3>
      Bateria dos fones e de outros dispositivos, incluindo AirPods esquerdo, direito e estojo, com aviso de bateria baixa.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>🌤️ Clima e copiados</h3>
      Temperatura ao lado do relógio com previsão por hora (Open‑Meteo), e os últimos 30 itens copiados, guardados só na memória.
    </td>
    <td valign="top">
      <h3>✋ Gestos e vibração</h3>
      Dois dedos trocam de música e mudam o volume. Vibração no trackpad com intensidade ajustável e uma área em forma de touchpad para testar.
    </td>
  </tr>
</table>

## Requisitos

- Mac com macOS 14 Sonoma ou mais novo. Macs sem notch também funcionam, com o painel na tela principal.
- Xcode 16 ou mais novo, ou as ferramentas de linha de comando dele: `xcode-select --install`
- Python 3, que vem com elas
- [Claude Code](https://docs.claude.com/en/docs/claude-code) é opcional e só serve para a aba Claude

## Instalação

```bash
git clone https://github.com/lleonardo-franco/notchy.git ~/Projects/notchy
cd ~/Projects/notchy
./install.sh
```

O instalador compila o app, copia para `/Applications`, conecta os hooks do Claude Code e instala o comando `notchy`. Na primeira vez ele também:

1. cria um certificado local de assinatura, **Notchy Local Signing**, e pede a senha do Mac uma vez para confiar nele;
2. abre a janela de boas-vindas, onde você libera só as permissões que quiser.

Como toda versão é assinada com o mesmo certificado, o macOS mantém as permissões entre as atualizações, e as próximas instalações só refazem o que mudou.

**Atualize** com `notchy update`. **Remova tudo** com `notchy uninstall`.

## Uso

| Comando | O que faz |
|---|---|
| `notchy` | Abre |
| `notchy stop` / `restart` | Fecha com a animação de desligar / reinicia |
| `notchy settings` | Abre os ajustes |
| `notchy welcome` | Mostra as boas-vindas e as permissões |
| `notchy city "Farroupilha"` | Define a cidade do clima (`notchy city auto` volta ao automático) |
| `notchy doctor` | Confere assinatura, certificado e permissões |
| `notchy update` | Baixa a versão mais nova e reinstala |
| `notchy uninstall` | Remove app, hooks, ajustes e o comando |

| Gesto com o notch aberto | Ação |
|---|---|
| Dois dedos para a direita / esquerda | Próxima / anterior (configurável) |
| Dois dedos para cima / baixo | Volume |
| Dois dedos para os lados num vídeo | Avança ou volta 10 s |

## Permissões

Tudo é opcional. O Notchy funciona com qualquer combinação delas.

| Permissão | Para quê |
|---|---|
| Acessibilidade | Ler os contadores (WhatsApp, Slack, Telegram, Discord, ClickUp) no Dock |
| Automação: Safari, Chrome | Encontrar vídeos do YouTube, pausar a aba e continuar no mesmo ponto |
| Automação: Spotify, Music | Mostrar e controlar a música |
| Automação: Terminal, iTerm | Ir até a sessão certa do Claude Code |
| Calendários | Próximas reuniões |
| Bluetooth | Bateria dos dispositivos |

> [!TIP]
> Para o vídeo continuar no segundo exato, ative **Permitir JavaScript de Eventos Apple** no menu Desenvolvedor do navegador. No Safari, mostre esse menu em Ajustes → Avançado → Mostrar recursos para desenvolvedores da Web.

## Como funciona

<details>
<summary>Visão geral da arquitetura</summary>

<br>

| Parte | Como |
|---|---|
| Janela | `NSPanel` acima da barra de menus, posicionado pelo `safeAreaInsets` da tela com notch |
| Música | Notificações distribuídas do Spotify e do Music, mais AppleScript |
| Claude Code | Hooks gravam o estado de cada sessão em `~/.notchy/sessions`; o hook `PermissionRequest` espera a resposta do notch; um wrapper da status line fornece a cota |
| Vídeo | AppleScript lê as abas do navegador; o player é a API de iframe do YouTube num `WKWebView` |
| Notificações | Contadores do Dock pela API de Acessibilidade |
| Bluetooth | `system_profiler SPBluetoothDataType` |
| Vibração | Motor do trackpad direto, para funcionar com o app em segundo plano |
| Tela cheia | Detecta Spaces de tela cheia para esconder o notch |

As verificações periódicas pausam com a tela bloqueada ou o Mac dormindo, e ficam mais espaçadas com o notch fechado.

```
Sources/Notchy/   app SwiftUI, serviços e views
hooks/            hooks e status line do Claude Code (Python, só biblioteca padrão)
bin/notchy        ferramenta de linha de comando
install.sh        instalador, assinatura e atualização incremental
build.sh          gera build/Notchy.app
```

</details>

## Perguntas frequentes

<details>
<summary><b>Por que pede minha senha na primeira instalação?</b></summary>
<br>
Para confiar no certificado local de assinatura e deixar o <code>codesign</code> usá-lo sem perguntar de novo. Acontece uma vez só. Sem uma assinatura estável, o macOS pediria todas as permissões de novo a cada atualização.
</details>

<details>
<summary><b>Ele manda meus dados para algum lugar?</b></summary>
<br>
Não. As únicas chamadas de rede são para o Open‑Meteo e um serviço de localização por IP, para o clima, e para o YouTube quando você assiste um vídeo no notch. O histórico de copiados fica na memória e some quando o app fecha.
</details>

<details>
<summary><b>Ele mexe na minha status line do Claude Code?</b></summary>
<br>
Não. O instalador envolve a status line que você já tem e mantém ela. O <code>notchy uninstall</code> devolve a original.
</details>

<details>
<summary><b>Tem um download pronto?</b></summary>
<br>
Ainda não. O Notchy é compilado no seu Mac a partir do código. Uma versão assinada e notarizada está no roadmap.
</details>

## Roadmap

- [ ] Interface em inglês e espanhol ([#1](https://github.com/lleonardo-franco/notchy/issues/1), [#2](https://github.com/lleonardo-franco/notchy/issues/2))
- [ ] Versões assinadas e notarizadas ([#9](https://github.com/lleonardo-franco/notchy/issues/9))
- [ ] Homebrew ([#8](https://github.com/lleonardo-franco/notchy/issues/8))
- [ ] Mais fontes de notificação: Slack, Telegram, Discord ([#4](https://github.com/lleonardo-franco/notchy/issues/4), [#5](https://github.com/lleonardo-franco/notchy/issues/5))
- [ ] Capturas de tela e vídeo de demonstração neste README ([#3](https://github.com/lleonardo-franco/notchy/issues/3))

Tem uma ideia? [Sugira uma funcionalidade](https://github.com/lleonardo-franco/notchy/issues/new/choose).

## Contribuindo

Contribuições de qualquer tamanho são bem-vindas: relatos de bugs, ideias, traduções, documentação e código. Leia o [guia de contribuição](CONTRIBUTING.pt-BR.md) para ver como fazer fork do repositório, preparar o projeto e abrir um pull request. Procure issues com a etiqueta [`good first issue`](https://github.com/lleonardo-franco/notchy/labels/good%20first%20issue) para começar.

Todo mundo que participa deve seguir o [Código de Conduta](CODE_OF_CONDUCT.md). Achou um problema de segurança? Veja o [SECURITY.md](SECURITY.md).

## Licença

[MIT](LICENSE) © Leonardo Franco Lima

<div align="center">
<sub>Se o Notchy deixou seu notch um pouco menos inútil, deixe uma ⭐</sub>
</div>
