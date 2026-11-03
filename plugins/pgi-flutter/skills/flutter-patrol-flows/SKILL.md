---
name: flutter-patrol-flows
description: Write, update and run Patrol end-to-end tests per flow on a simulator/emulator for a Nextline PGI Flutter project (UNITED, FinsofApp and their versions) — one test file per flow with a declared entry point, fixed routines for the first login on a device and the login from the inactivity screen, session preloaded by API so flows never repeat the login UI, and checkpoints that recover from failures (overlays → pop → native back → soft restart) and from a lost session (403 → restart → inactivity → password). Use this whenever the user asks to test, probar, automatizar, verificar or "correr las pruebas" of a flow or screen, mentions Patrol, integration test, prueba E2E, prueba en simulador/emulador, regresión, or "automatiza el login"; and at the end of figma-hu-to-flutter / flutter-feature-scaffold to create or update the flow's test. Trigger even if the user only says "pruébalo" after building a flow.
---

# Patrol flow tests

Each flow of the app has one Patrol test that starts at the flow's **entry point** with a valid session, walks the flow's steps, and asserts each screen. Login is tested only by its two fixed routines. Tests stay in the repo as the regression suite.

## Step 0 — Resolve project values

Read the **Test variables** table in the project's `CLAUDE.md`. If it is missing, the project is not set up yet: do **Setup** first.

| Variable | UNITED | Meaning |
|---|---|---|
| tests dir | `patrol_test/` | Patrol 4 default |
| harness | `patrol_test/common/` | `flow_test.dart`, `app_harness.dart`, `session.dart`, `flow_steps.dart`, `screens.dart`, `test_env.dart` |
| routines | `patrol_test/routines/` | `login_routines.dart`, `navigation_routines.dart` |
| flows | `patrol_test/flows/<flow>_test.dart` | one file per flow |
| main flow | Home → Alcancía (Wallet) → Detalles de inversión | Finsof-like projects: Home → Portafolio → Detalles de inversión |
| credentials | `patrol_test/test_env.json` (gitignored) | `TEST_EMAIL`, `TEST_PASSWORD` |
| default flavor | `<project>Dev` | `<project>Qa` only when the user asks |
| session lost / rejected screens | `LoginEmailPage` + "La sesión ha expirado…" / `RejectedAccountPage` | what the auth interceptor shows on 403 / 401 |

## Modes

Pick the mode from the request. Do not ask about anything the request already says.

| Request | Mode |
|---|---|
| "configura Patrol", project without `patrol_test/` | **Setup** |
| A new full flow was just built (figma-hu-to-flutter, flutter-feature-scaffold) | **Write** + **Run** that flow — automatic, no need to ask |
| A change to an existing flow | **Update** that flow's test + **Run** that flow only |
| "prueba / corre el flujo X" | **Run** X |
| "corre todas las pruebas", "en QA" | **Run** the suite / on `<project>Qa` — only when explicitly asked |

### Setup (once per project)

Follow `references/patrol-setup.md`: dependencies and `patrol:` block in `pubspec.yaml`, Android runner, iOS `RunnerUITests` target, testable `bootstrap()`, the harness files and the two login routines. Then add the **Test variables** table to `CLAUDE.md`.

### Write / Update a flow test

1. **Find the flow's entry point** and the route that reaches it from the Dashboard. Reuse a routine in `navigation_routines.dart` if one exists; otherwise add one there (never inside the test file) so other flows can reuse it as their entry or exit.
2. **Write `patrol_test/flows/<flow>_test.dart`** using the template in `references/flow-test-format.md`:
   - `flowTest(...)` instead of `patrolTest(...)`: it captures the app's uncaught async errors so they are reported as `ERROR_APP` instead of killing the run.
   - `FlowRunner(entry: <navigation routine>, entryProbe: Screens.<entry>)` → `flow.start()`.
   - One `flow.step()` per user action + assertion. Mark a `Checkpoint` after each screen that is safe to come back to.
   - `flow.finish()` at the end.
3. **Independence:** the test must pass on its own. If it depends on another flow only to arrive or leave, call that flow's navigation routine — do not repeat its assertions. Never call `loginFresh` from a flow test.
4. **Finders**, in this order: existing `Key` → `Screens.<page>` (by type) → text from the ARB / hardcoded copy → icon. Add a `Key('<screen>_<element>')` to the app widget only when a finder is ambiguous, and say so in the report.
5. Add new page probes and copy to `common/screens.dart`, not inline.
6. `flutter analyze patrol_test` must be clean.

### Run

Always run through the skill's script, from the Flutter project root:

```bash
<skill-dir>/scripts/run_flow.sh patrol_test/flows/<flow>_test.dart [dev|qa] [device-id] [timeout_s]
<skill-dir>/scripts/run_flow.sh all qa          # whole suite, only when asked
```

It resolves the flavor id from `lib/main_<project>_<flavor>.dart`, runs `patrol test --show-flutter-logs` (without it the `[FLOW]` lines are not printed), prints only the report lines and the log path, and **stops Patrol when the summary appears or at the timeout** — on iOS, Patrol can hang after a failed test. Exit: 0 green, 1 failures, 2 timeout, 3 usage error.

- Run **only the flow being worked on**. The whole suite or `qa` only when asked. Never `prod` — the script and the harness refuse it.
- Before running, check: `patrol_test/test_env.json` exists (if not, ask the user to create it from `test_env.example.json`; **never write credentials yourself**), and a device is available (`xcrun simctl list devices booted`, `adb devices`).
- If there is no device or no credentials, leave the test written and report it as **pendiente de correr**.
- `patrol` lives in `~/.pub-cache/bin`; install with `dart pub global activate patrol_cli` if missing. Android needs `ANDROID_HOME` and `adb` in `PATH`.

### Report

Parse the `[FLOW <name>]` lines of the output (format in `references/checkpoints.md`) and report:

1. Flow, flavor, device, result.
2. Each `FALLA` with screen, visible texts and what it means — app bug, test bug, or data (e.g. test user without investments). Each `ERROR_APP` is an app bug (an exception nobody catches, typically a provider rethrowing inside `..init()`): report it with its file, not as a test failure to fix.
3. Each `RECUPERADO` level used and any `SESION_PERDIDA` / `ABORTADO`.
4. Keys added to the app and app bugs noticed (do not fix app bugs inside the test change unless asked).

When fixing, re-run **only the failed flow file**. Diagnostic tests go in `patrol_test/_scratch/` (gitignored) and are deleted when done.

## Fixed routines

Contract and adaptation per project in `references/routines.md`. Summary:

| Routine | Pre | Post |
|---|---|---|
| `loginFresh($)` | none (wipes the device) | Home; onboarding skipped; biometrics denied |
| `loginFromInactivity($)` | session stored | Home, entered with password from the inactivity screen |
| `launchAt($, entry)` | none | entry point, session from `ensureSession()` (API), no login UI |
| `goToHome / goToSavings / goToInvestmentDetails` | Dashboard | that screen |

## Failure handling

Details in `references/checkpoints.md`.

- **Flow failure:** evidence (screen, visible texts, Android screenshot) → back to the last checkpoint via the ladder **overlays → pop → native back → soft restart (`launchAt`) → abort** → continue with the next step. Never walks screens outside the flow.
- **Session lost (403):** restart app → inactivity screen → password → back to the checkpoint → retry the step **once**. Twice = abort ("la cuenta de prueba se está usando en otro dispositivo o el back invalida el token").
- **Account rejected (401):** abort, no retry.

## Test lifecycle

- Tests are versioned and stay in the repo. Delete one only when its flow is removed from the app. When a flow changes, update its test in the same change.
- New full flow → its test is created automatically and run on `<project>Dev`.

## Anti-patterns

| ❌ Don't | ✅ Do | Why |
|---|---|---|
| `loginFresh` at the start of every flow test | `FlowRunner(...).start()` → `launchAt` | Login UI is tested once; the rest start from their entry |
| Hardcode email/password or commit `test_env.json` | `--dart-define-from-file`, gitignored file | Credentials never in code or in the skill |
| One test file walking several unrelated flows | One file per flow | A failure in one flow must not block the others |
| Navigation steps written inline in the test | A routine in `navigation_routines.dart` | Other flows reuse it as entry/exit |
| Waiting the real inactivity time (2000 s dev) | `launchApp(inactivitySeconds: shortInactivitySeconds)` | Seconds instead of minutes |
| `pumpAndSettle()` on screens with infinite animations | `waitUntilVisible` / `pumpAndTrySettle` | Skeletons and spinners never settle |
| Retrying a failed step in a loop | Recover to the checkpoint and continue; retry only on session loss, once | Retries hide real bugs |
| Running the full suite after each fix | Run only the failed flow | Faster loop, same signal |

## Finish

Start the report with `Skill aplicada: flutter-patrol-flows`, then the Report section above.
