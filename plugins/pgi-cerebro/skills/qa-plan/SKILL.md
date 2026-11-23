---
name: qa-plan
description: Arma el plan de pruebas de un issue del repo cerebro de un proyecto PGI (HU de producto, requerimiento o bug) - un caso por criterio de aceptación (CA / CT), con nivel de prueba (unitaria, e2e de API, e2e de App, manual en BackOffice), datos, resultado esperado y prioridad - y lo publica en el issue. Úsala cuando pidan "plan de pruebas", "casos de prueba", "qué hay que probar", "QA de…", o desde las skills spec e implementar. Funciona en modo desatendido para el orquestador.
---

# Plan de pruebas

El equipo no tiene QA dedicado: este plan es el contrato de calidad del issue. Cada fila se
convierte en una prueba automática (skill `qa-e2e`) o en un paso de QA manual con su frame de Figma.

## 1. Entrada

- `gh issue view <n> --repo <cerebro> --comments`: criterios de la HU (`CA…`), del spec (`CT-n`),
  sección **Dinero**, **Alcance por repo** y, si es HU, la copia en `docs/producto/…`
  (estados por frame, copies, reglas `RN…`, tabla de backend).
- Lee el `CLAUDE.md` de cada repo afectado: dice qué tipos de prueba existen y cómo se corren.
- Si ya hay un comentario `## Plan de pruebas` del bot, actualízalo en lugar de duplicarlo.
- **Ahorro de tokens:** de la copia de la épica lee solo la sección de la HU
  (`grep -n "^## HU-NN.n"` y lee ese rango); no abras código salvo para confirmar un endpoint.
  El plan es una tabla, sin prosa extra.

## 2. Reglas para armar los casos

- **Uno o más casos por criterio.** Ningún `CA`/`CT` queda sin caso. Si un criterio es solo
  visual, su caso es manual y cita el frame (`[40:515](link)`).
- **Nivel más bajo que lo pruebe de verdad:**
  - Regla de cálculo o validación pura → **unitaria** (API).
  - Endpoint, permisos, persistencia, efectos en saldos → **e2e API** (Jest + MySQL en Docker).
  - Flujo de pantallas de la App → **e2e App** (Patrol, skill `pgi-flutter:flutter-patrol-flows`).
  - Pantallas del BackOffice → **manual** con frame de Figma (aún no hay pruebas automáticas).
- **Siempre incluir**, aunque la HU no lo diga:
  - Permisos: el rol correcto puede; otro rol recibe 403; un cliente no ve datos de otro.
  - Errores: datos inválidos (406), recurso inexistente (404), sesión inválida (401/403).
  - Los 4 estados obligatorios de la HU cuando aplica a pantallas: datos, vacío, cargando, error.
  - Compatibilidad: respuestas existentes no cambian de forma (la App publicada no se rompe).
- **Dinero** (inversiones, rendimientos, depósitos, retiros, wallet/alcancía, saldos): e2e API
  obligatorio con montos reales y redondeo, saldo antes y después, doble envío / reintento
  (idempotencia) y concurrencia cuando aplique. Prioridad **P1**.
- **Prioridad:** P1 dinero, seguridad y permisos; P2 flujo principal; P3 bordes y textos.
- No inventes reglas: si un resultado esperado no está en la HU, el spec o `docs/domain/`,
  márcalo `[por confirmar]` y agrégalo a Preguntas abiertas del issue.

## 3. Formato

```markdown
## Plan de pruebas

| ID | Criterio | Nivel | Caso | Datos / precondición | Resultado esperado | Prioridad |
|---|---|---|---|---|---|---|
| QA-1 | CA1.2.8 | e2e API | Login con contraseña incorrecta | Usuario de prueba del seed | 406, detail genérico, no dice si falló correo o contraseña | P1 |
| QA-2 | CA1.2.8 | Manual App | Mensaje en pantalla | Frame [40:515](…) | Texto exacto «Correo o contraseña incorrectos.» | P3 |

**Cobertura:** N criterios · N casos automáticos · N manuales · criterios sin caso: ninguno.
**Datos de prueba:** usuarios y registros del seed que se usan, o cómo se crean en la prueba.
```

Los IDs `QA-n` son estables por issue: al actualizar el plan conserva los existentes y agrega al final.

## 4. Publicar

- Modo interactivo: muestra el plan y pide confirmación.
- `gh issue comment <n> --repo <cerebro> --body-file <archivo>` (o edita el comentario previo
  del plan). No cambies labels.
- Si te llamó `spec`, el plan va dentro de la sección **Plan de pruebas** del spec en vez de un
  comentario aparte.
