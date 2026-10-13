# Contribuir a Notchy

[English](CONTRIBUTING.md) · [Português](CONTRIBUTING.pt-BR.md) · **Español**

¡Gracias por querer ayudar! Notchy es un proyecto pequeño y cada contribución cuenta, desde corregir una errata hasta una pestaña nueva. Esta guía explica cómo proponer cambios mediante un **fork y un pull request**.

## Contenido

- [Formas de contribuir](#formas-de-contribuir)
- [Antes de empezar](#antes-de-empezar)
- [Fork, rama, pull request](#fork-rama-pull-request)
- [Mantener tu fork al día](#mantener-tu-fork-al-día)
- [Preparar el entorno](#preparar-el-entorno)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Estilo de código](#estilo-de-código)
- [Mensajes de commit](#mensajes-de-commit)
- [Pruebas](#pruebas)
- [Documentación y traducciones](#documentación-y-traducciones)
- [Revisión y merge](#revisión-y-merge)

## Formas de contribuir

| | Cómo |
|---|---|
| 🐞 Reportar un error | [Abre un reporte de error](https://github.com/lleonardo-franco/notchy/issues/new?template=bug_report.yml) con la salida de `notchy doctor` |
| 💡 Proponer una función | [Abre una propuesta](https://github.com/lleonardo-franco/notchy/issues/new?template=feature_request.yml) describiendo el problema que resuelve |
| 🌍 Traducir | Traduce la documentación o ayuda a llevar la interfaz a más idiomas |
| 📝 Mejorar la documentación | Corrige lo que esté confuso, desactualizado o falte |
| 🛠️ Programar | Elige un issue, sobre todo los que tienen la etiqueta [`good first issue`](https://github.com/lleonardo-franco/notchy/labels/good%20first%20issue) o [`help wanted`](https://github.com/lleonardo-franco/notchy/labels/help%20wanted) |

Los issues y pull requests en español, inglés o portugués son bienvenidos.

## Antes de empezar

- **Busca primero.** Puede que alguien ya haya reportado el error o propuesto la idea.
- **Abre un issue antes de cambios grandes.** Para cualquier cosa más allá de un arreglo pequeño, describe lo que quieres hacer y espera el visto bueno. Así no construyes algo que no se va a integrar.
- **Avisa que tomas el issue.** Comenta en él para que los demás sepan que estás trabajando en ello.
- **Los problemas de seguridad** nunca van en issues públicos. Sigue [SECURITY.md](SECURITY.md).

## Fork, rama, pull request

No necesitas permisos de escritura en el repositorio. Todos los cambios entran por pull request desde tu propio fork.

**1. Haz un fork** del repositorio con el botón **Fork** arriba en [la página del repo](https://github.com/lleonardo-franco/notchy). Esto crea `github.com/<tu-usuario>/notchy`.

**2. Clona tu fork** y añade el repositorio original como `upstream`:

```bash
git clone https://github.com/<tu-usuario>/notchy.git
cd notchy
git remote add upstream https://github.com/lleonardo-franco/notchy.git
```

**3. Crea una rama** desde la `main` más reciente. Nunca trabajes directamente en `main`.

```bash
git fetch upstream
git switch -c feat/descripcion-corta upstream/main
```

| Prefijo | Para |
|---|---|
| `feat/` | Funciones nuevas |
| `fix/` | Corrección de errores |
| `docs/` | Documentación |
| `i18n/` | Traducciones |
| `refactor/` | Cambios de código que no alteran el comportamiento |
| `chore/` | Build, CI, herramientas |

**4. Haz tus cambios**, luego compila y prueba (mira [Preparar el entorno](#preparar-el-entorno) y [Pruebas](#pruebas)).

**5. Haz commit** siguiendo los [Mensajes de commit](#mensajes-de-commit) y **súbelo a tu fork**:

```bash
git push -u origin feat/descripcion-corta
```

**6. Abre el pull request.** GitHub muestra un botón **Compare & pull request** en tu fork. Comprueba que la base sea `lleonardo-franco/notchy` → `main`, completa la plantilla y enlaza el issue con `Closes #123`. Deja marcado **Allow edits by maintainers** para que los arreglos pequeños se puedan subir directamente a tu rama.

**7. Atiende la revisión.** Sube nuevos commits a la misma rama para responder a los comentarios. El pull request se actualiza solo.

## Mantener tu fork al día

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
```

Para actualizar la rama en la que trabajas:

```bash
git switch feat/descripcion-corta
git rebase upstream/main
git push --force-with-lease
```

## Preparar el entorno

**Requisitos:** macOS 14 o posterior, Xcode 16 o sus herramientas de línea de comandos (`xcode-select --install`), Python 3.

```bash
swift build              # comprobación rápida de compilación
./build.sh               # genera build/Notchy.app
./install.sh             # instala en /Applications, rehaciendo solo lo que cambió
./install.sh --force     # reinstalación completa
```

Usa `./install.sh` para probar tus cambios. Firma la app con tu certificado local **Notchy Local Signing**, así macOS conserva los permisos entre compilaciones. Ejecutar `build/Notchy.app` con firma ad‑hoc funciona, pero macOS pedirá los permisos cada vez.

Útil para depurar:

| | |
|---|---|
| `notchy doctor` | Firma, certificado, permisos y si la app está en ejecución |
| `notchy restart` | Reinicia después de instalar |
| `~/.notchy/sessions/` | Un JSON por sesión de Claude Code, escrito por los hooks |
| `~/.notchy/approvals/` | Solicitudes de permiso pendientes y sus respuestas |
| `~/Library/Application Support/Notchy/status.json` | Estado de los permisos escrito por la app |

## Estructura del proyecto

| Ruta | Qué contiene |
|---|---|
| `Sources/Notchy/AppDelegate.swift` | Ventana del panel, seguimiento del ratón, gestos, pantallas y pantalla completa |
| `Sources/Notchy/NotchModel.swift` | Estado de la app: modos, pestañas, tamaños y conexión entre servicios |
| `Sources/Notchy/*Service.swift` | Un servicio por integración: música, Claude, calendario, clima, portapapeles, notificaciones, Bluetooth, multimedia del navegador |
| `Sources/Notchy/*Views.swift`, `NotchView.swift` | Vistas SwiftUI |
| `Sources/Notchy/Preferences.swift`, `SettingsView.swift` | Ajustes y su ventana |
| `Sources/Notchy/PermissionCenter.swift`, `WelcomeView.swift` | Comprobación de permisos y bienvenida |
| `hooks/` | Hooks de Claude Code, wrapper de la status line y su instalador |
| `bin/notchy` | Herramienta de línea de comandos |
| `install.sh`, `build.sh` | Instalador y script de build |
| `Resources/` | `Info.plist` y el icono de la app |

## Estilo de código

- **Swift y SwiftUI.** Los modelos usan `@Observable`; el código de interfaz se ejecuta en el main actor. Los servicios se encargan de los efectos secundarios; las vistas se mantienen simples.
- **Sin comentarios en el código.** Prefiere nombres claros y funciones pequeñas que se expliquen solas.
- **Sigue los patrones existentes.** Usa la misma nomenclatura, organización y formato del código que editas.
- **Nunca bloquees el hilo principal.** Ejecuta AppleScript con `AppleScript.run`, que tiene un tiempo límite.
- **Respeta el reposo y el bloqueo.** Los timers y las comprobaciones periódicas no deben trabajar mientras `SystemActivity.shared.paused` sea verdadero.
- **¿Permiso nuevo?** Añádelo a `PermissionCenter`, a la ventana de bienvenida, al texto de uso de `Info.plist` y a la tabla de permisos de todos los README.
- **Los hooks** usan solo la biblioteca estándar de Python y deben funcionar con el `/usr/bin/python3` del sistema.
- **Los scripts de shell** deben funcionar con el bash 3.2 que trae macOS.
- **Los textos de la interfaz** se escriben en portugués de Brasil en el código y se traducen en `i18n/translations.py`. Usa `Text("…")` para textos fijos y `String(localized: "…")` para textos construidos en el código, y luego añade las versiones en inglés y español (mira [Documentación y traducciones](#documentación-y-traducciones)).

## Mensajes de commit

Usa [Conventional Commits](https://www.conventionalcommits.org/es/), en inglés:

```
feat(video): add playback speed control
fix(calendar): show weekday for events after tomorrow
docs: explain how to enable JavaScript from Apple Events
i18n(es): translate the contributing guide
```

Mantén cada commit centrado en un solo cambio. Un cuerpo corto explicando el *porqué* siempre ayuda.

## Pruebas

Todavía no hay pruebas automáticas de interfaz, así que las pruebas manuales importan:

1. Ejecuta `./install.sh` y prueba lo que cambiaste.
2. Recorre las secciones relacionadas del [plan de pruebas](TESTING.md).
3. Indica en el pull request qué probaste y en qué Mac y versión de macOS.

Cada pull request se compila con [GitHub Actions](https://github.com/lleonardo-franco/notchy/actions) en macOS. El build debe pasar antes del merge.

## Documentación y traducciones

El README y esta guía existen en inglés, portugués y español.

- Si cambias uno, actualiza también los demás. Si no puedes, dilo en el pull request y alguien te ayudará.
- Para añadir un idioma, crea `README.<código>.md` y `CONTRIBUTING.<código>.md` (por ejemplo `README.fr.md`) y añade el enlace arriba en todas las versiones.
- La interfaz de la app se traduce en `i18n/translations.py`, con el texto en portugués como clave, `%@` para texto y `%lld` para números enteros. Después de editarlo, ejecuta `python3 i18n/generate.py` para generar los archivos `.strings` en `Resources/`, y `python3 i18n/check.py` para listar textos del código que aún no tienen traducción.
- Para añadir un idioma a la app, añade una columna en `translations.py`, enseña a `generate.py` a usarla y pon el código del idioma en `CFBundleLocalizations` en `Resources/Info.plist`.

Añade una línea describiendo tu cambio en **Unreleased** en [CHANGELOG.md](CHANGELOG.md).

## Revisión y merge

- Un mantenedor revisa los pull requests, normalmente en pocos días.
- Es posible que se pidan cambios; es parte normal del proceso.
- Los pull requests se integran con squash merge, así que el título se convierte en el mensaje del commit. Escríbelo como un Conventional Commit.

Al contribuir, aceptas que tu trabajo quede bajo la [licencia MIT](LICENSE) y que seguirás el [Código de Conducta](CODE_OF_CONDUCT.md).
