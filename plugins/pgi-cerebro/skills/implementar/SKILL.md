---
name: implementar
description: Implementa un issue aprobado (label `ready`) del repo cerebro de un proyecto PGI - crea la misma rama en cada repo afectado, hace el cambio con pruebas y abre un PR por repo hacia su rama de integración. La usa el orquestador en modo desatendido; también sirve en una sesión de dev ("implementa el issue #12").
---

# Implementar un issue aprobado

Objetivo: un PR por repo afectado, con el cambio mínimo, pruebas que pasan y una descripción
que un dev pueda revisar en minutos. **Nunca mergeas**: el merge lo hace una persona.

## 0. Modo y permisos

- **Desatendido** (argumentos con `desatendido`): no hay nadie a quien preguntar. Si algo
  bloquea, comenta en el issue, pon `bloqueado` y termina.
- **Interactivo**: confirma el plan (paso 2) antes de tocar código.
- La aprobación para crear ramas, hacer commit, push y abrir PRs es el label `ready` que puso
  una persona en el issue. Es la excepción documentada en el ADR del orquestador a la regla
  "no git sin aprobación" de los `CLAUDE.md`. Solo cubre **tu rama del issue**: nunca hagas
  push, merge ni reset sobre `dev`, `qa`, `demo`, `main`, `master` o `prod`.

## 1. Validar el issue

- `gh issue view <n> --repo <cerebro> --comments`.
- Debe tener `ready` y un spec con las secciones de la skill `spec` (Criterios de aceptación,
  Alcance por repo, Dinero, Plan de pruebas, Rama). Si falta algo o hay **Preguntas abiertas**
  sin responder, comenta qué falta, pon `necesita-info`, quita `ready` y termina.
- Pon `en-progreso`. Si `Dinero` es Sí, pon también `dinero`.

## 2. Plan

- Lee el `CLAUDE.md` del cerebro (repos, ramas de integración, reglas) y el `CLAUDE.md` de
  **cada repo que vas a tocar**, antes de tocarlo. Sus reglas mandan sobre esta skill.
- Lee solo el doc de dominio del tema. Nunca `docs/domain/_fuentes/`.
- Orden: backend primero, luego BackOffice y App. Si el cliente depende de un endpoint nuevo,
  el PR del cliente enlaza al PR del backend.
- Escribe el plan como comentario en el issue: por repo, archivos y funciones que cambian, y
  pruebas que agregarás.

## 3. Por cada repo, en orden

1. Rama: el nombre de la sección **Rama** del spec, desde `origin/<rama de integración>`.
   Si la rama ya existe en el remoto (re-ejecución), continúa sobre ella; no la reescribas.
2. Cambio mínimo, con el estilo del archivo (nombres, idioma, finales de línea). No reformatees
   ni toques código ajeno al issue.
3. Base de datos: sigue la skill de migraciones del repo (en UNITED, `migracion-bd`).
4. Pruebas, según el `CLAUDE.md` del repo:
   - Backend: agrega pruebas unitarias o e2e del caso; corre solo los archivos afectados.
     Si toca dinero, **e2e obligatorio**.
   - BackOffice: lint.
   - App: `flutter analyze` y `flutter test` de lo que tocaste.
   - Si una prueba falla y no la puedes arreglar en 3 intentos, sigue con PR en **draft** y
     explica el fallo.
5. Commits en Conventional Commits, en español, con `Refs <org>/<cerebro>#<n>`.
6. Push de la rama y PR hacia la rama de integración:
   `gh pr create --repo <org>/<repo> --base <integración> --head <rama> --body-file <archivo>`.
   Cuerpo:
   ```markdown
   ## Issue
   <org>/<cerebro>#<n>
   ## Cambio
   ## Pruebas
   Comandos corridos y resultado.
   ## Dinero
   No aplica | Requiere aprobación humana del cálculo (regla 5).
   ## Riesgos
   ## PRs relacionados
   ```
   Draft si hay pruebas fallando, dudas o si toca dinero.

## 4. Nunca

- Escribir secretos, leer `.env` o copiar valores de `constants.js` u otros archivos con credenciales.
- Modificar `.github/workflows/`, configuración de CI o infraestructura.
- Cambiar o borrar campos que usa la App publicada (solo agregar).
- Hacer cambios fuera del alcance del spec. Si encuentras otro bug, menciónalo en el PR.

## 5. Cierre

- Comenta en el issue: un renglón por PR con enlace, estado (listo / draft) y pruebas.
- Quita `en-progreso` y pon `en-revision` (o `bloqueado` si no se abrió ningún PR).
- Los devs revisan en el PR; si piden cambios con `@claude`, se atienden sobre la misma rama.
