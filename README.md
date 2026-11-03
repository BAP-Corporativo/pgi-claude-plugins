# Marketplace `pgi` — plugins de Claude Code para PGI

Plugins compartidos por los proyectos de PGI (UNITED, FinsofApp y sus versiones). Decisión y
contexto en `united-platform/docs/decisions/0002-marketplace-plugins.md`.

| Plugin | Versión | Mantenedor | Qué trae |
|---|---|---|---|
| [`pgi-flutter`](plugins/pgi-flutter) | 1.1.0 | Joel Anaya | Convenciones de las apps Flutter |
| [`pgi-cerebro`](plugins/pgi-cerebro) | 0.3.0 | BAP-Corporativo | Skills del repo cerebro de cada proyecto |
| `pgi-api` | — | IT-BAP | Pendiente: skills `pgi-*` del backend |

## `pgi-flutter`

| Skill | Cuándo se activa |
|---|---|
| `flutter-feature-scaffold` | Crear un feature, pantalla o flujo nuevo |
| `flutter-api-endpoint` | Consumir un endpoint, crear o cambiar un DTO |
| `flutter-intl-strings` | Agregar o cambiar textos (ARB + intl_utils) |
| `flutter-add-flavor` | Agregar un ambiente / flavor |
| `flutter-build-release` | Generar APK / IPA por flavor (IPA solo en macOS) |
| `figma-css-to-flutter` | Traducir CSS de Figma a widgets |
| `figma-hu-to-flutter` | Implementar un flujo desde el HU de diseño + nodos de Figma, reutilizando widgets |
| `flutter-patrol-flows` | Escribir y correr pruebas E2E por flujo con Patrol en simulador (login fijo, checkpoints, sesión por API) |

Cada skill funciona sola. `figma-hu-to-flutter` es la única que orquesta a las demás; al terminar un flujo, `figma-hu-to-flutter` y `flutter-feature-scaffold` crean o actualizan su prueba con `flutter-patrol-flows` si el proyecto ya tiene `patrol_test/`:

| Pides | Se usa |
|---|---|
| Un flujo completo desde su HU / Figma | `figma-hu-to-flutter` → `flutter-feature-scaffold` + `flutter-api-endpoint` + `flutter-intl-strings` + `flutter-patrol-flows` |
| Probar un flujo en simulador | `flutter-patrol-flows` |
| Solo una pantalla nueva sin diseño | `flutter-feature-scaffold` |
| Solo integrar un endpoint o un mock | `flutter-api-endpoint` |
| Solo textos | `flutter-intl-strings` |
| CSS pegado de Figma | `figma-css-to-flutter` |

Las skills no tienen valores de proyecto fijos: leen la tabla **Project variables** del
`CLAUDE.md` de cada repo, o los descubren con `pubspec.yaml` y `lib/main_*_*.dart`.

Prompt de ejemplo para un flujo completo:

```
Implementa el flujo "Simulador de inversión" (HU en el índice de flujos).
Endpoints (disponibles | mock acordado):
- GET client/investment/simulator/levels?currency_id={id}
  <JSON>
- GET client/investment/simulator?currency_id={id}&amount={monto}
  <JSON>
Divisas: MXN=3, USD=?, EUR=?
Entrada: opción "Simular inversión" del bottom sheet de la alcancía.
Salida: "Invertir" → flujo de nueva inversión con monto y divisa precargados.
Alcance de esta sesión: brief + capa de datos. La UI en la siguiente.
```

**En automatización desatendida:** las skills `figma-*` necesitan Figma y Google Drive con login
de una persona, y `flutter-build-release` necesita macOS para el IPA y credenciales de rclone.
Úsalas en sesiones de devs; el orquestador usa solo las demás.

## `pgi-cerebro`

| Skill | Cuándo se activa |
|---|---|
| `spec` | Convertir un requerimiento o bug en un spec triado y publicarlo como issue en el repo cerebro (label `spec`; `ready` lo pone una persona). Necesita `gh` |
| `implementar` | Implementar un issue con `ready`: misma rama en cada repo afectado, cambio con pruebas y un PR por repo hacia su rama de integración. Nunca mergea. Necesita `gh` |
| `capturar-conocimiento` | Entrevistar a un dev y escribir `docs/knowledge/<area>-<nombre>.md` en el repo cerebro |

Ejemplo: abre Claude Code en la carpeta del proyecto (p. ej. `PGI UNITED/`) y pide
"haz el spec de: el admin necesita exportar los retiros del mes a Excel", o "triar el issue #12".

## Instalar

Dentro de Claude Code (una vez por máquina):

```
/plugin marketplace add BAP-Corporativo/pgi-claude-plugins
/plugin install pgi-flutter@pgi
/plugin install pgi-cerebro@pgi
```

Para declararlo en un repo y que se instale solo al abrirlo, agrega a su `.claude/settings.json`
y commitéalo:

```json
{
  "extraKnownMarketplaces": {
    "pgi": { "source": { "source": "github", "repo": "BAP-Corporativo/pgi-claude-plugins" } }
  },
  "enabledPlugins": { "pgi-flutter@pgi": true }
}
```

En el servidor y en el orquestador, fija una versión con `"ref": "<tag>"` dentro de `source`.

**Si ya tenías `nextline-pgi-flutter@nextline-pgi`:** desinstálalo y vuelve a instalar como
`pgi-flutter@pgi`; el plugin y el marketplace cambiaron de nombre.

## Versiones

- Cada plugin declara `version` en su `.claude-plugin/plugin.json`. Súbela en el mismo PR que
  cambia el plugin (semver: parche para correcciones, menor para skills nuevas, mayor si cambia
  cómo se usa).
- Cada release lleva un tag `<plugin>-v<versión>` (p. ej. `pgi-flutter-v1.0.0`).
- Actualizar: `claude plugin update pgi-flutter@pgi`, o activa el auto-update en
  `/plugin` → Marketplaces.

## Desarrollar y probar sin publicar

```bash
claude --plugin-dir ./plugins/pgi-flutter
claude plugin validate .
```

## Agregar un plugin

1. Crea `plugins/<nombre>/.claude-plugin/plugin.json` con `name`, `version`, `description` y `author`.
2. Pon sus skills en `plugins/<nombre>/skills/<skill>/SKILL.md`.
3. Regístralo en `.claude-plugin/marketplace.json` y en la tabla de este README.
4. Nada de credenciales, hosts ni datos de clientes en las skills.
