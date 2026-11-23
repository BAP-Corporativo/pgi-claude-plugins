---
name: importar-hu
description: Importa las historias de usuario (HU) de un documento de épica de UX/UI (Google Docs "HU <PROYECTO> · <Plataforma> · EP-NN · <Nombre>") al repo cerebro de un proyecto PGI - guarda una copia en markdown en docs/producto/ y crea o actualiza un issue por HU para el orquestador. Úsala cuando alguien diga "importa la épica EP-03", "sube las HU de…", "actualiza las HU", "sincroniza producto" o pase un link a un documento de épica o al índice de HU. Requiere una persona con los conectores de Google Docs/Drive y Figma.
---

# Importar HU de una épica al cerebro

Los documentos de épica de UX/UI son la **fuente de verdad funcional**. Esta skill no los
reescribe ni los interpreta: los copia al cerebro para que el orquestador (que no tiene acceso a
Drive ni a Figma) los pueda leer, y deja un issue por HU listo para triage.

## 0. Requisitos

- Sesión interactiva con los conectores de **Google Docs** (o Google Drive) y **Figma**. Si no
  están, di cuál falta y cómo conectarlo; no sigas.
- Estar en el repo cerebro (tiene `docs/producto/README.md`). Léelo: trae el ID de la carpeta de
  Drive, el `fileKey` de Figma y las convenciones del proyecto.
- `gh` con sesión y permiso de escritura en el repo cerebro.

## 1. Qué importar

- Entrada: una o varias épicas (`EP-03`), un link a su documento, o "todas".
- Lee primero el **índice** (`HU <PROYECTO> · 00 · Índice y reglas generales`): tabla de
  documentos por épica (estado), correspondencia con Figma, reglas comunes `R-xx`, decisiones y
  temas abiertos `TT`. Si una épica está "Pendiente" o sin documento, dilo y sáltala.
- Muestra a la persona la lista de épicas y HU que vas a importar y pide confirmación.

## 2. Copia en markdown (por épica)

Escribe `docs/producto/<plataforma>/EP-NN-<slug>.md` (plataforma en minúsculas: `app`, `web`,
`backoffice`). Reglas:

- **Copia fiel**: mismas secciones, tablas y textos. No resumas, no corrijas copies, no inventes.
  Conserva los IDs tal cual (`HU-NN.n`, `CA…`, `RN…`, `T…`, `R-xx`) aunque su formato sea
  inconsistente; anota la inconsistencia en el reporte final.
- Encabezado con: título del doc, ID del doc de Google, versión del documento, fecha de
  importación y un aviso: "Copia de lectura. Se edita en Google Docs y se vuelve a importar."
- Convierte cada node ID de Figma (`40:515`) en enlace:
  `[40:515](https://www.figma.com/design/<fileKey>/?node-id=40-515)`. En celdas con varios nodos
  separados por " · ", enlaza cada uno.
- Actualiza también `docs/producto/indice.md` con la copia del índice (mismas reglas).
- Si el archivo ya existe, reemplázalo completo y muestra el `git diff --stat`.

## 3. Estado de cada HU

Por cada HU determina su **madurez**:

- `hu-v1.1` (lista para desarrollo): la tabla "Datos que se envían al backend → acciones /
  endpoints" tiene endpoints definidos, o la sección dice "No aplica", o el Estatus de la ficha es
  "Con backend V1.1".
- `hu-v1` (solo producto): la tabla de endpoints está vacía o dice "Pendiente de backend".
  El documento lo dice explícito: no está lista para desarrollo.
- **Excepción:** si el issue ya tiene `contrato-aprobado`, el contrato se aprobó en GitHub
  (vive en el spec del issue) y la HU se queda en `hu-v1.1` aunque la tabla del documento siga
  vacía. Si la tabla del documento trae datos distintos al contrato aprobado, comenta la
  diferencia en el issue y no cambies labels.

## 4. Issues (uno por HU)

Busca si ya existe: `gh issue list --repo <cerebro> --state all --search "[HU-NN.n] in:title"`.

- **Título**: `[HU-NN.n] <Título de la HU>`.
- **Cuerpo** (escríbelo en un archivo temporal y usa `--body-file`):
  ```markdown
  **Épica:** EP-NN · <Nombre> · **Plataforma:** <App|Web|Backoffice> · **Etapa:** <…> · **Origen:** <…>
  **Fuente de verdad:** [Documento de la épica](<link Google Doc>) · Copia en el repo: `docs/producto/<plataforma>/EP-NN-<slug>.md#hu-nn-n`
  **Figma:** [Sección](<link node sección>) · Frames: [Initial](…) · [Empty](…) · [Loading](…) · [Error](…)
  **Madurez:** V1 (falta contrato de backend) | V1.1 (lista para desarrollo)

  ## Historia
  Como … quiero … para …

  ## Criterios de aceptación
  | ID | Dado | Cuando | Entonces |
  (copiados del documento, sin la columna Frame)

  ## Dependencias
  ```
- **Labels**: `hu`, `hu-v1` o `hu-v1.1`, y `triage` si es nueva o si cambió desde la última
  importación (para que el orquestador regenere el spec técnico). Plataforma: no agregues labels
  extra si no existen.
- **Issue existente**: si el contenido cambió, reemplaza el cuerpo y deja un comentario
  "Actualizada desde el documento (versión X): <qué cambió en 1–3 líneas>". Si pasó de `hu-v1`
  a `hu-v1.1`, cambia el label. Nunca quites `ready`, `en-progreso`, `en-revision` ni
  `contrato-aprobado`; si una HU en progreso cambió, avísalo en el reporte. Pon `triage` solo si
  cambió algo funcional (historia, criterios, copies, reglas, estados); un cambio que solo copia
  el contrato ya aprobado no lo necesita.
- Si un label no existe, no lo crees: avisa (los crea `orq-labels`).

## 5. Commit y reporte

- Antes de commit, muestra a la persona: archivos cambiados, issues que se crean o actualizan y
  cuáles pasan a V1.1. Espera su aprobación.
- Rama `docs/hu-EP-NN` (o `docs/hu-sync-<fecha>` si son varias), commit
  `docs(producto): importar EP-NN versión X`, push y PR hacia `main` del cerebro. No mergees.
- Reporte final: épicas importadas, HU nuevas / actualizadas / sin cambios, cuáles quedaron
  en V1 y en V1.1, e inconsistencias del documento que conviene avisar a UX/UI (IDs repetidos o
  con formato distinto, node IDs que no existen en Figma, secciones faltantes).

## Nunca

- Editar los documentos de Google ni el archivo de Figma.
- Copiar datos personales reales; los documentos usan datos dummy, consérvalos así.
- Cambiar textos marcados como copies oficiales.
