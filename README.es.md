<div align="center">

<img src="docs/icon.png" width="112" alt="Icono de Notchy">

# Notchy

**El notch de tu MacBook, por fin útil.**<br>
Música, Claude Code, calendario, YouTube y notificaciones justo donde está la cámara.

[![Release](https://img.shields.io/github/v/release/lleonardo-franco/notchy?color=d97757&label=versión)](https://github.com/lleonardo-franco/notchy/releases)
[![Build](https://github.com/lleonardo-franco/notchy/actions/workflows/build.yml/badge.svg)](https://github.com/lleonardo-franco/notchy/actions/workflows/build.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111?logo=apple)](#requisitos)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](Package.swift)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-3b82f6)](LICENSE)
[![PRs bienvenidos](https://img.shields.io/badge/PRs-bienvenidos-22c55e)](CONTRIBUTING.es.md)

[English](README.md) · [Português](README.pt-BR.md) · **Español**

<br>

<img src="docs/hero.svg" width="100%" alt="Notchy abierto bajo el notch del MacBook, con la canción actual, sesiones de Claude Code y pestañas">

</div>

---

Notchy convierte el notch en un pequeño centro de control. Recogido, muestra solo lo importante a los lados de la cámara: la portada del álbum, el estado de Claude Code, la cuenta atrás para la próxima reunión, notificaciones. Pasa el ratón y se abre con el reproductor, pestañas y controles. Ciérralo y se apaga como un televisor antiguo. La interfaz habla español, inglés y portugués, según el idioma de tu Mac.

## Contenido

- [Funciones](#funciones)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso](#uso)
- [Permisos](#permisos)
- [Cómo funciona](#cómo-funciona)
- [Preguntas frecuentes](#preguntas-frecuentes)
- [Hoja de ruta](#hoja-de-ruta)
- [Contribuir](#contribuir)
- [Licencia](#licencia)

## Funciones

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎵 Música</h3>
      Spotify y Apple Music con portada, título y controles, y también otras apps (navegador, Podcasts, VLC…) en las versiones de macOS que permiten leer "Ahora suena" a otras apps. Arrastra la barra de progreso para saltar. El notch toma un tono del color de la portada.
    </td>
    <td width="50%" valign="top">
      <h3>🤖 Claude Code</h3>
      Estado de cada sesión en tiempo real. <b>Aprueba o rechaza solicitudes de permiso desde el notch</b>, salta a la pestaña correcta de Terminal o iTerm y sigue tu cuota de 5 horas y de 7 días.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>▶️ YouTube en el notch</h3>
      ¿Tienes un vídeo en Safari, Chrome, Brave, Edge o Chromium? Envíalo a un mini reproductor bajo el notch. Sigue en el mismo segundo y a la misma velocidad, y vuelve a la pestaña cuando termines.
    </td>
    <td valign="top">
      <h3>📅 Calendario</h3>
      Próximos eventos con botón <b>Unirse</b> para Zoom, Meet, Teams y Webex, y una cuenta atrás en el notch recogido antes de cada reunión.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>🔔 Notificaciones</h3>
      Contadores animados de WhatsApp, Slack, Telegram, Discord y ClickUp, con el icono de cada app.
    </td>
    <td valign="top">
      <h3>🎧 Bluetooth</h3>
      Batería de auriculares y otros dispositivos, incluidos AirPods izquierdo, derecho y estuche, con avisos de batería baja.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>🌤️ Clima y portapapeles</h3>
      Temperatura junto al reloj con pronóstico por horas (Open‑Meteo), y lo último que copiaste (30 elementos), guardado solo en memoria.
    </td>
    <td valign="top">
      <h3>✋ Gestos y vibración</h3>
      Dos dedos cambian de canción y ajustan el volumen. Vibración del trackpad con intensidad ajustable y un área con forma de touchpad para probarla.
    </td>
  </tr>
</table>

## Requisitos

- Un Mac con macOS 14 Sonoma o posterior. Los Mac sin notch también funcionan, con el panel en la pantalla principal.
- Xcode 16 o posterior, o sus herramientas de línea de comandos: `xcode-select --install`
- Python 3, que viene con ellas
- [Claude Code](https://docs.claude.com/en/docs/claude-code) es opcional y solo hace falta para la pestaña Claude

## Instalación

```bash
git clone https://github.com/lleonardo-franco/notchy.git ~/Projects/notchy
cd ~/Projects/notchy
./install.sh
```

El instalador compila la app, la copia a `/Applications`, conecta los hooks de Claude Code e instala el comando `notchy`. La primera vez además:

1. crea un certificado local de firma, **Notchy Local Signing**, y pide la contraseña del Mac una vez para confiar en él;
2. abre una ventana de bienvenida donde concedes solo los permisos que quieras.

Como cada versión se firma con el mismo certificado, macOS conserva los permisos entre actualizaciones, y las siguientes instalaciones solo rehacen lo que cambió.

**Actualiza** con `notchy update`. **Elimina todo** con `notchy uninstall`.

## Uso

| Comando | Qué hace |
|---|---|
| `notchy` | Abre la app |
| `notchy stop` / `restart` | Cierra con la animación de apagado / reinicia |
| `notchy settings` | Abre los ajustes |
| `notchy welcome` | Muestra la bienvenida y los permisos |
| `notchy city "Madrid"` | Define la ciudad del clima (`notchy city auto` vuelve a la automática) |
| `notchy doctor` | Revisa firma, certificado y permisos |
| `notchy update` | Descarga la última versión y reinstala |
| `notchy uninstall` | Elimina la app, los hooks, los ajustes y el comando |

| Gesto con el notch abierto | Acción |
|---|---|
| Dos dedos a la derecha / izquierda | Siguiente / anterior (configurable) |
| Dos dedos arriba / abajo | Volumen |
| Dos dedos a los lados en un vídeo | Avanza o retrocede 10 s |

## Permisos

Todo es opcional. Notchy funciona con cualquier combinación de ellos.

| Permiso | Para qué |
|---|---|
| Accesibilidad | Leer los contadores (WhatsApp, Slack, Telegram, Discord, ClickUp) en el Dock |
| Automatización: Safari, Chrome | Encontrar vídeos de YouTube, pausar la pestaña y seguir en el mismo punto |
| Automatización: Spotify, Music | Mostrar y controlar la música |
| Automatización: Terminal, iTerm | Ir a la sesión correcta de Claude Code |
| Calendarios | Próximas reuniones |
| Bluetooth | Batería de los dispositivos |

> [!TIP]
> Para que el vídeo siga en el segundo exacto, activa **Permitir JavaScript de Apple Events** en el menú Desarrollo del navegador. En Safari, muestra ese menú en Ajustes → Avanzado → Mostrar funciones para desarrolladores web.

## Cómo funciona

<details>
<summary>Resumen de la arquitectura</summary>

<br>

| Parte | Cómo |
|---|---|
| Ventana | Un `NSPanel` sobre la barra de menús, posicionado con el `safeAreaInsets` de la pantalla con notch |
| Música | Notificaciones distribuidas de Spotify y Music, más AppleScript |
| Claude Code | Los hooks guardan el estado de cada sesión en `~/.notchy/sessions`; el hook `PermissionRequest` espera la respuesta del notch; un wrapper de la status line aporta la cuota |
| Vídeo | AppleScript lee las pestañas del navegador; el reproductor es la API IFrame de YouTube en un `WKWebView` |
| Notificaciones | Contadores del Dock mediante la API de Accesibilidad |
| Bluetooth | `system_profiler SPBluetoothDataType` |
| Vibración | El motor del trackpad directamente, para que funcione con la app en segundo plano |
| Pantalla completa | Detecta Spaces en pantalla completa para ocultar el notch |

Las comprobaciones periódicas se pausan con la pantalla bloqueada o el Mac en reposo, y se espacian con el notch cerrado.

```
Sources/Notchy/   app SwiftUI, servicios y vistas
hooks/            hooks y status line de Claude Code (Python, solo biblioteca estándar)
bin/notchy        herramienta de línea de comandos
install.sh        instalador, firma y actualizaciones incrementales
build.sh          genera build/Notchy.app
```

</details>

## Preguntas frecuentes

<details>
<summary><b>¿Por qué pide mi contraseña en la primera instalación?</b></summary>
<br>
Para confiar en el certificado local de firma y que <code>codesign</code> lo use sin volver a preguntar. Solo ocurre una vez. Sin una firma estable, macOS pediría todos los permisos de nuevo tras cada actualización.
</details>

<details>
<summary><b>¿Envía mis datos a algún sitio?</b></summary>
<br>
No. Las únicas llamadas de red son a Open‑Meteo y a un servicio de geolocalización por IP, para el clima, y a YouTube cuando reproduces un vídeo en el notch. El historial del portapapeles vive en memoria y desaparece al cerrar la app.
</details>

<details>
<summary><b>¿Toca mi status line de Claude Code?</b></summary>
<br>
No. El instalador envuelve tu status line actual y la mantiene. <code>notchy uninstall</code> restaura la original.
</details>

<details>
<summary><b>¿Hay una descarga lista para usar?</b></summary>
<br>
Todavía no. Notchy se compila en tu Mac desde el código. Una versión firmada y notarizada está en la hoja de ruta.
</details>

## Hoja de ruta

- [x] Interfaz en inglés, portugués y español
- [ ] Versiones firmadas y notarizadas ([#9](https://github.com/lleonardo-franco/notchy/issues/9))
- [ ] Homebrew ([#8](https://github.com/lleonardo-franco/notchy/issues/8))
- [ ] Más fuentes de notificaciones: Slack, Telegram, Discord ([#4](https://github.com/lleonardo-franco/notchy/issues/4), [#5](https://github.com/lleonardo-franco/notchy/issues/5))
- [ ] Capturas y un vídeo de demostración en este README ([#3](https://github.com/lleonardo-franco/notchy/issues/3))

¿Tienes una idea? [Propón una función](https://github.com/lleonardo-franco/notchy/issues/new/choose).

## Contribuir

Toda contribución es bienvenida: reportes de errores, ideas, traducciones, documentación y código. Lee la [guía de contribución](CONTRIBUTING.es.md) para saber cómo hacer fork del repositorio, preparar el proyecto y abrir un pull request. Busca issues con la etiqueta [`good first issue`](https://github.com/lleonardo-franco/notchy/labels/good%20first%20issue) para empezar.

Se espera que todas las personas que participan sigan el [Código de Conducta](CODE_OF_CONDUCT.md). ¿Encontraste un problema de seguridad? Mira [SECURITY.md](SECURITY.md).

## Licencia

[MIT](LICENSE) © Leonardo Franco Lima

<div align="center">
<sub>Si Notchy hizo tu notch un poco menos inútil, déjale una ⭐</sub>
</div>
