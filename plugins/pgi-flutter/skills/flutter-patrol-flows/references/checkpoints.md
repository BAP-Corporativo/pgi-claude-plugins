# Checkpoints, recovery and session guard

Implemented in `patrol_test/common/flow_steps.dart` (`FlowRunner`).

## Step lifecycle

```
step(title, body, reached?)
  ├─ body() ok → session guard ok → "OK" → reached? becomes the checkpoint
  ├─ session lost (403)        → recover session → retry once → second time: ABORT
  ├─ account rejected (401)    → ABORT
  └─ any other failure         → capture evidence → recovery ladder → next step
```

**Uncaught app errors.** Many providers rethrow inside a fire-and-forget `..init()` (e.g. `InvestmentDetailsProvider.init` on a 403). Under flutter_test an uncaught async error ends the test at once and Patrol may hang. `flowTest()` initializes the Patrol binding inside a guarded zone and registers the frame callbacks there, so builds driven by the engine (and their futures) report to `AppErrors` instead. After each step the runner turns them into `ERROR_APP` lines and step failures, then the session guard runs as usual.

Flow failures are **not** retried: the step is recorded as failed, the app goes back to the checkpoint and the next step runs. `finish()` fails the test listing every failed step.

## Session guard

After every step (and when a step throws) the runner checks the visible screen:

| Seen | Cause (UNITED `AuthInterceptor`) | Action |
|---|---|---|
| `LoginEmailPage` or snackbar "La sesión ha expirado. Por favor, inicia sesión nuevamente." | 403: token expired or someone else logged in with the test account. `AuthService.logout` does **not** wipe storage | `launchApp` (restart with storage intact → inactivity screen) → `unlockWithPassword` → `entry` → `checkpoint.reach` → retry the step once |
| `RejectedAccountPage` | 401 | Abort, report as a test-account problem |

Before a flow starts, `ensureSession()` refreshes the token if it is expired or unreadable, so a flow never begins on the Dashboard with a dead token.

## Recovery ladder

Stops at the first level where the checkpoint probe is visible:

1. **Overlays:** unfocus (keyboard), pop a visible `Dialog` / `AlertDialog` / `BottomSheet`.
2. **Pop:** `navigatorKey.currentState.maybePop()` up to 6 times (respects `PopScope`).
3. **Native back:** Android `pressBack`, iOS `swipeBack`, up to 2 times.
4. **Soft restart:** `launchAt(entry)` + `checkpoint.reach` — re-mounts the app with a valid session. Covers screens replaced with `pushAndRemoveUntil` / `Get.offAll` and corrupted stacks (UNITED's Wallet back button pushes a new `DashboardPage` instead of popping).
5. **Abort:** if the soft restart fails too (framework exception, hung app). The next test file starts with a clean app (Android `clearPackageData`); Patrol cannot kill and relaunch the native process inside a test.

## Output format

Every runner line is printed as `[FLOW <name>] <EVENT> ...`:

| Event | Meaning |
|---|---|
| `INICIO en entrada (<screen>)` | flow started at its entry |
| `OK <step>` | step passed |
| `CHECKPOINT <name>` | new safe screen |
| `FALLA "<step>" en pantalla <screen>: <error>` | step failed |
| `TEXTOS VISIBLES: a \| b \| c` | up to 25 visible texts at failure time |
| `RECUPERADO nivel <n> <how> → <checkpoint>` | ladder level that worked |
| `ERROR_APP en "<step>": <error>` | uncaught app exception during the step (app bug); also printed raw as `[APP_ERROR]` |
| `SESION_PERDIDA en "<step>": ...` | 403 detected, session recovery started |
| `ABORTADO en "<step>": <reason>` | flow stopped |
| `FIN OK` / `FIN <n> falla(s)` | summary |

Android also saves a native screenshot per failure (`takeNativeScreenshot`), tagged `<flow>_<step>`.

## Per project

The session-lost and rejected screens come from the CLAUDE.md **Test variables** table. If a project's interceptor behaves differently (e.g. wipes storage on 403), adapt `_recoverSession` to use `loginFresh` instead of the inactivity screen and note it in the table.
