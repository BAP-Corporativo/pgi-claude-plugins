---
name: spec
description: Convierte un requerimiento o bug de un proyecto PGI en un spec triado, listo para aprobar con el label `ready`, y lo publica como issue en el repo cerebro. Úsala cuando alguien pida "hacer un spec", "triar", "especificar", "levantar un requerimiento", "crear el issue de…", o pase un issue con label `triage`. También la usa el orquestador en modo desatendido.
---

# Spec de un requerimiento o bug

Objetivo: que un dev o el orquestador pueda implementar el cambio **sin volver a preguntar**.
El resultado es un issue en el repo cerebro con el spec en el cuerpo, label `spec` y sin
`triage`. La aprobación (`ready`) siempre la pone una persona.

## 0. Modo

- **Interactivo** (por defecto): hay una persona en la sesión; preguntas y confirmas.
- **Desatendido**: los argumentos traen `desatendido` (lo usa el orquestador). No preguntes:
  lo que falte va a **Preguntas abiertas**, pon label `necesita-info` en vez de `spec` y termina.

## 1. Arranque

- Ubica el repo cerebro: el que tiene `docs/domain/README.md` y un `CLAUDE.md` con el mapa de
  la plataforma (en UNITED, `united-platform`). Si no está en la sesión ni junto a ella, pide la ruta.
- Lee su `CLAUDE.md`: repos, ramas de integración, reglas. **Esas reglas mandan sobre esta skill.**
- Entrada:
  - Un número de issue → `gh issue view <n> --repo <cerebro> --comments`.
  - Texto libre → es un requerimiento nuevo; crearás el issue al final.
- Clasifica: **requerimiento** (rama `feat/`) o **bug** (rama `fix/`).
- Si el issue tiene label `hu` (lo creó `importar-hu`), sigue además **1b**.

## 1b. Issues de HU de producto

El documento de la épica (UX/UI) es la fuente de verdad funcional. **No reescribas** la historia,
los criterios, los copies ni las reglas: el spec agrega lo técnico.

- Lee la sección de la HU en la copia del repo (`docs/producto/<plataforma>/EP-NN-*.md`, ruta en
  el issue) y, del índice (`docs/producto/indice.md`), solo las reglas `R-xx`, decisiones y temas
  `TT` que la HU cita. No abras Drive ni Figma: si la copia no está, pide correr `importar-hu`.
- **Criterios de aceptación** del spec: lista los IDs de la HU (`CA1.2.1` … `CA1.2.8`) sin
  copiarlos, y agrega solo criterios técnicos nuevos con ID `CT-n` (permisos, compatibilidad,
  concurrencia, dinero).
- **Contrato de backend**: si la tabla "Datos que se envían al backend" de la HU está vacía,
  propón el contrato en una sección `## Contrato de backend propuesto`, con el mismo formato que
  la HU: `Acción | Endpoint | Formato y validación | Respuestas y códigos de error | Estado`
  (Estado = "Propuesto"). Reusa endpoints existentes (busca en `contracts/api-endpoints.md` y en
  el código) antes de proponer uno nuevo; respeta la respuesta estándar `{ detail, content }` y
  la regla de no romper la App publicada.
- **Origen "Existente"**: ubica la pantalla y el endpoint actuales en el código y di qué cambia
  respecto a lo que ya hay.
- Si el documento contradice `docs/domain/`, el código o una regla del cerebro, no elijas: va a
  **Preguntas abiertas** indicando a quién (UX/UI, negocio o backend).
- Una HU con label `hu-v1` queda en `spec` con esta nota al final: "Para pasar a V1.1: backend
  aprueba el contrato propuesto, UX/UI lo copia al documento de la épica y se vuelve a correr
  `importar-hu`." El orquestador no implementa HU en V1.

## 2. Contexto (lee poco y dirigido)

1. `docs/domain/README.md` y **solo** los archivos del tema. Nunca `docs/domain/_fuentes/`.
2. Si cruza un tema con hallazgos abiertos, revisa `docs/domain/_hallazgos-*.md` (grep del tema).
3. Contrato: grep en `contracts/api-endpoints.md` por la ruta o el recurso. No lo leas entero.
4. Arquitectura y trampas: `docs/architecture/<repo>.md`, solo la sección que aplica.
5. Código: grep puntual en los repos hermanos para confirmar qué existe hoy (endpoint,
   controlador, tabla, pantalla). Para archivos grandes usa el mapa del `CLAUDE.md` de ese repo.
   Cita `archivo:función`, no números de línea.
6. Bug: reproduce el razonamiento con evidencia (código, datos del issue). Propón causa raíz
   solo si la ves en el código; si no, dilo.

## 3. Preguntas (modo interactivo)

Antes de escribir, haz **en una sola ronda** las preguntas que bloquean el spec (máx. 5):
montos y redondeo, quién puede hacerlo (rol), qué pasa en el caso borde, compatibilidad con
versiones viejas de la App, qué se notifica. Si algo contradice `docs/domain/`, pregúntalo
explícitamente. Lo que no bloquea va a **Preguntas abiertas**.

## 4. Spec

Usa esta estructura. Omite secciones que no apliquen escribiendo "No aplica" (no las borres:
el orquestador las busca por título).

```markdown
## Resumen
Una o dos frases: qué cambia y para quién.

## Contexto de negocio
Por qué. Reglas de `docs/domain/<archivo>.md` que aplican (enlázalas).

## Criterios de aceptación
- [ ] Dado … cuando … entonces … (con números reales si hay montos, fechas o divisas)
- [ ] Casos borde: …
- [ ] Permisos: quién sí y quién no.

## Alcance por repo
En el orden de implementación (API primero, luego clientes).

### <Repo backend>
- Endpoints nuevos o cambiados: método, ruta, auth, request y response (JSON de ejemplo).
- Compatibilidad: solo agregar campos o endpoints; si algo se renombra o elimina, versión nueva
  del endpoint y ADR.
- Base de datos: tablas y columnas; va por la skill de migraciones del repo (`migracion-bd` en UNITED).
- Lugares en el código: `archivo:función`.

### <Repo BackOffice>
Pantallas, permisos y textos.

### <Repo App>
Pantallas, flujo, textos (idiomas) y comportamiento con versiones viejas instaladas.

## Dinero
¿Toca inversiones, rendimientos, depósitos, retiros, alcancía o saldos? Sí/No.
Si es Sí: requiere tests e2e en el backend y aprobación humana explícita del cálculo.

## Plan de pruebas
Casos que QA (o `qa-plan`) debe cubrir: felices, borde, permisos, concurrencia si hay dinero.

## Riesgos
Seguridad, datos existentes, migración, hallazgos abiertos relacionados.

## Fuera de alcance
Lo que no entra en este issue.

## Preguntas abiertas
- [ ] …

## Rama
`feat/<issue>-<slug>` (o `fix/…`), la misma en todos los repos que toca.
```

Reglas de redacción: español, frases cortas, verificable. **Nunca** escribas secretos, hosts
internos, datos personales de clientes ni valores de `.env`; si el pedido trae uno, escribe
solo dónde vive.

## 5. Publicar

- Modo interactivo: muestra el spec completo y pide confirmación antes de publicar.
- Issue nuevo: `gh issue create --repo <cerebro> --title "[REQ] …" | "[BUG] …" --body-file <archivo> --label spec`
  (escribe el cuerpo en un archivo temporal; no lo pases en la línea de comandos).
- Issue existente: reemplaza el cuerpo solo si el autor lo pide; si no, agrega el spec como
  comentario. Luego `gh issue edit <n> --add-label spec --remove-label triage`.
- Si `gh` no está instalado o no hay permiso, deja el spec en un archivo y di cómo publicarlo.
- Si un label no existe, no lo crees: avisa (los labels los crea quien configura el orquestador).
- Calcula la rama con el número real del issue y actualiza la sección **Rama**.

## 6. Cierre

Reporta: enlace del issue, repos afectados, si toca dinero, preguntas abiertas y qué falta
para `ready`. No crees ramas, no toques código y no pongas `ready`.
