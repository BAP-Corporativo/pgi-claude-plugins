---
name: qa-e2e
description: Escribe y corre las pruebas automáticas del plan de pruebas de un issue PGI en el repo que corresponde - e2e y unitarias del API (Jest + MySQL en Docker), e2e de la App (Patrol) - nombrando cada prueba con el ID del criterio que cubre, y reporta la cobertura. Úsala cuando pidan "escribe las pruebas", "prueba e2e de…", "cubre los criterios", "corre las pruebas del API", o desde la skill implementar. Funciona en modo desatendido.
---

# Pruebas automáticas por criterio

Convierte las filas automáticas del **Plan de pruebas** (skill `qa-plan`) en pruebas reales,
las corre y deja la tabla de cobertura para el PR.

## 0. Antes de escribir

- Lee el `CLAUDE.md` del repo: comandos, configuración de Jest/Patrol, helpers y datos de prueba.
  Esas convenciones mandan sobre esta skill.
- Lee 1 o 2 pruebas existentes del mismo módulo y copia su estructura. No inventes helpers si ya
  existe uno.
- Sin plan de pruebas en el issue: corre primero `qa-plan`.
- **Ahorro de tokens:** no leas archivos de prueba completos (usa `grep -n` y `offset`/`limit`);
  corre solo los archivos afectados con `--silent`; de un fallo copia solo el bloque del error
  (`| tail -n 40`), nunca el log entero; no vuelvas a leer un archivo que acabas de editar.

## 1. Nombres y trazabilidad

- Cada `it`/`test` empieza con el ID del criterio y el del caso:
  `it('CA1.2.8 · QA-1 rechaza credenciales inválidas sin decir cuál falló', …)`.
- Un archivo por funcionalidad, junto a los del mismo módulo
  (UNITED: `tests/e2e/<módulo>/<tema>.e2e.test.js`, `tests/unit/<ruta del src>.test.js`).

## 2. API (Node + Jest) — en UNITED, `UnitedAPI`

- **E2E**: llaman al servidor real (`SERVER_URL` de `tests/SERVER_CONFIGURATION.js`) con los
  tokens de `tests/helpers/auth.js`; aíslan datos con `resetTestData` en `beforeAll`; crean sus
  datos por API dentro de la prueba. Verifican código HTTP, forma `{ detail, content }` y el
  efecto en base de datos cuando el caso lo pide (saldos, estatus, bitácora).
- **Dinero**: saldo antes y después con montos exactos; doble envío del mismo request; si aplica,
  dos requests en paralelo (`Promise.all`) y que solo uno tenga efecto.
- **Permisos**: el mismo endpoint con el rol que no debe poder (403) y con otro cliente (no ve
  datos ajenos).
- **Esquema**: si la prueba necesita tablas o datos nuevos, sigue la skill de migraciones del repo
  (`migracion-bd`): `base_query.sql` + `database/schema.sql` / `seed.sql`.
- Correr solo lo afectado:
  - `npm test <archivo>` (unitarias, sin Docker).
  - `npm run test:e2e <archivo>` (e2e, necesita Docker).
  - Nunca `npx jest` directo: pierde la configuración del repo.
- Una prueba debe **fallar sin el cambio y pasar con él**. Si es un bug, escribe primero la
  prueba que lo reproduce y confirma que falla.

## 3. App (Flutter) — en UNITED, `UnitedApp`

- Usa la skill `pgi-flutter:flutter-patrol-flows` (un archivo por flujo, sesión precargada por API,
  checkpoints). Pon el ID del criterio en el nombre de cada `patrolTest`.
- Patrol necesita simulador o emulador: en el orquestador (Linux, sin simulador) **no** se corre;
  escribe la prueba, corre `flutter analyze` y marca en la tabla "escrita, pendiente de correr".

## 4. BackOffice

- Aún no tiene pruebas automáticas. Los casos quedan como **QA manual** con el link al frame.
  No agregues un framework de pruebas sin una decisión (ADR) del equipo.

## 5. Reporte

Al terminar, devuelve (y pega en el PR, sección **Criterios cubiertos**):

```markdown
| Criterio | Caso | Prueba | Resultado |
|---|---|---|---|
| CA1.2.8 | QA-1 | tests/e2e/auth/login-errores.e2e.test.js | pasa |
| CA1.2.8 | QA-2 | QA manual · frame [40:515](…) | pendiente |
```

Más: comandos corridos, cuántas pruebas pasan / fallan y, si algo falla, la causa en una línea.
Si una prueba falla 3 veces y no es por tu cambio (flaky o del entorno), dilo explícito; no la
borres ni la marques como skip.
