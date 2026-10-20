# QuitAll

**Cierra todas las apps abiertas con un clic, menos las que elijas: a esas las ocultas o las dejas como están.**

[English](README.md) · macOS 13+ · Apple Silicon e Intel · licencia MIT · sin red ni cuentas

Al acabar el día, al ponerte a estudiar o antes de compartir pantalla quieres un Mac limpio sin ir cerrando apps una a una. Abre QuitAll desde Spotlight, Alfred o Raycast y listo: **abrir la app ejecuta Cerrar todo**. O usa su icono ⏻ de la barra de menús (opcional) para ver antes qué va a pasar.

- **Eliges qué se queda** en desplegables por categoría (Navegadores, Comunicación, Productividad, Música y audio, Desarrollo, Sistema…), con el icono y el nombre de cada app. La categoría sale del `LSApplicationCategoryType` de cada app y la puedes cambiar a mano.
- Para cada app elegida: **Ocultar** o **Dejar como está**. Todas las demás: **Cerrar**.
- **Cierre educado**: QuitAll pide a cada app que se cierre igual que ⌘Q, así que cada una muestra su propio diálogo de *¿guardar cambios?*. Pasados unos segundos (configurable) te dice cuáles siguen abiertas —normalmente porque esperan a que guardes— con **Mostrar**, **Forzar** y **Dejar abierta** para cada una.
- **Deshacer**: reabre las apps que cerró la última acción y vuelve a mostrar las que ocultó.
- **Preajustes seguros**: Finder y QuitAll nunca se cierran, ni las piezas del sistema (Dock, Centro de control, ventana de inicio…). Las apps de música empiezan en *Ocultar*: siguen sonando, pero fuera de la vista.
- **Atajo global** (por defecto ⌃⌥⌘Q, configurable), **abrir al iniciar sesión** opcional, **perfiles** opcionales (p. ej. *Estudio*, *Concentración*) con listas distintas, español/inglés.

## Instalación

**Homebrew** (compila en tu Mac con las Command Line Tools: sin avisos de Gatekeeper):

```bash
brew install jdevesablanco/tap/quitall
quitall install        # copia QuitAll.app a /Applications y abre la configuración inicial
```

O la app ya compilada: `brew install --cask jdevesablanco/tap/quitall`.

**Instalador (.pkg)** — sin Terminal: descarga `QuitAll-x.y.z.pkg` de [Releases](https://github.com/jdevesablanco/QuitAll/releases), haz **clic derecho → Abrir** (solo la primera vez) y sigue los pasos. Instala en *Aplicaciones* y abre la configuración inicial.

**DMG**: descarga `QuitAll-x.y.z.dmg` de [Releases](https://github.com/jdevesablanco/QuitAll/releases) y arrastra la app a *Aplicaciones*. La primera vez, **clic derecho en QuitAll → Abrir**.

QuitAll está firmada *ad-hoc* y **no está notarizada** por Apple (hace falta una cuenta de Apple Developer de pago; ver [docs/NOTARIZATION.md](docs/NOTARIZATION.md)). Por eso macOS pide confirmación la primera vez: clic derecho → *Abrir*, o *Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente*. O sin diálogo: `xattr -dr com.apple.quarantine /Applications/QuitAll.app`.

**Desde el código**: `git clone https://github.com/jdevesablanco/QuitAll && cd QuitAll && Scripts/build-app.sh && open build/QuitAll.app`

## Primer uso

Tres pasos cortos (selector ES/EN arriba a la derecha): qué hace QuitAll → qué apps no se cierran (por categorías) → cómo quieres lanzarlo (atajo, menú Servicios, abrir al iniciar sesión). La última pantalla muestra las otras apps del pack.

## Formas de lanzar «Cerrar todo»

| Dónde | Cómo |
|---|---|
| Spotlight, Alfred, Raycast | Escribe «QuitAll» y pulsa ↩: abrir la app ejecuta **Cerrar todo** con tus excepciones. Mantén ⇧ al abrirla para ir a Ajustes. Se cambia en *Ajustes → Lanzar*. |
| Barra de menús | Clic en ⏻ → **Cerrar todo**. Toca el icono de una app ahí para alternar cerrar → ocultar → dejar. Clic derecho en ⏻: menú rápido. |
| Teclado | Atajo global, ⌃⌥⌘Q por defecto (*Ajustes → Lanzar*). No pide permiso de Accesibilidad. |
| Menú Servicios | Menú de cualquier app → *Servicios* → **QuitAll: cerrar todo** (se instala desde la app). Le puedes dar su propio atajo en *Ajustes del Sistema → Teclado → Funciones rápidas → Servicios*. |
| Launchpad, Dock | Basta con abrir QuitAll (⌘Espacio → «QuitAll» → ↩, o fíjala en el Dock y haz clic): al abrirla **ejecuta Cerrar todo** al momento. Nunca se dispara al iniciar sesión ni justo después de instalarla. ¿Prefieres ver el menú? *Ajustes → Lanzar → Al abrir QuitAll → Mostrar el menú*. |
| URL | `open quitall://quit`, `open "quitall://quit?profile=Estudio"`, `open quitall://undo` |
| App Atajos | *Abrir URL* con `quitall://quit`, o *Ejecutar script de shell* con `quitall quit` |
| Terminal | `quitall quit` (ver abajo) |

## Línea de comandos

```bash
quitall plan                       # qué pasaría con cada app abierta, sin tocar nada
quitall quit                       # cierra con educación según el perfil activo
quitall quit --profile Estudio --force --timeout 5
quitall undo                       # reabre lo que cerró la última acción y muestra lo que ocultó
quitall rule Spotify keep          # cambia una regla (quit | hide | keep)
quitall profiles                   # lista los perfiles (* = activo)
quitall apps                       # apps instaladas con su categoría y regla
quitall selftest                   # prueba de humo, no cierra nada
```

La terminal desde la que lanzas `quitall` nunca se cierra (añade `--include-terminal` si quieres que también).

## Limitaciones

- macOS no deja saber a otras apps si un documento tiene cambios sin guardar. QuitAll solo ve que una app sigue abierta después de pedirle que se cierre; si tiene una ventana en pantalla, casi siempre es el diálogo de *¿guardar cambios?*, y así lo indica.
- **Deshacer** reabre las apps; qué ventanas y documentos recupera cada una depende de ella y de *Ajustes del Sistema → Escritorio y Dock → Cerrar ventanas al salir de una app*.
- Solo se cierran apps normales (las que tienen icono en el Dock). Las utilidades de la barra de menús y los procesos de fondo no se tocan.
- El icono de la barra de menús es opcional (*Ajustes → Lanzar*). Sin él, usa QuitAll desde Spotlight/Alfred/Raycast, el atajo o el Dock; para llegar a Ajustes, mantén ⇧ al abrirla o pulsa ⚙︎ en el aviso que sale tras cerrar.
- Los perfiles son opcionales: el activo es el que usan el botón, el atajo y el Servicio; se elige en la barra de menús.

Los ajustes están en `~/Library/Application Support/QuitAll/settings.json`.

## Privacidad

Todo ocurre en tu Mac. Sin telemetría. Solo se usa la red cuando *tú* pulsas **Instalar** en una app del pack (API pública de GitHub / Homebrew).

## Combina bien con

Del mismo autor, gratis y open source:

| App | Qué hace | Estado |
|---|---|---|
| [SplitExercises](https://github.com/jdevesablanco/SplitExercises) | Divide PDFs de ejercicios en una hoja por ejercicio, con clic derecho | Disponible |
| **QuitAll** | Cierra todas las apps de un clic, menos las que elijas | Esta app |

La app muestra las mismas tarjetas (en la última pantalla de bienvenida y en *Ajustes → Combina bien con*), detecta cuáles tienes e instala las demás con Homebrew o con el último `.pkg` de GitHub.

## Desarrollo

- `Sources/QuitAllCore`: catálogo de apps y categorías, apps protegidas, cierre educado y deshacer (solo frameworks de Apple).
- `Sources/QuitAllApp`: app de barra de menús en SwiftUI/AppKit. `PackCatalog.swift` es idéntico en todas las apps del pack.
- `Sources/QuitAllCLI`: el comando `quitall`.
- `QUITALL_SNAPSHOT=/dir build/QuitAll.app/Contents/MacOS/QuitAll` renderiza las pantallas de bienvenida a PNG; `QUITALL_CONFIG_DIR=/dir` aísla los ajustes.

## Licencia

MIT © 2026 Julio Devesa Blanco
