# Fixed routines

Routines are the only code that touches login and the main navigation. Flow tests call them; they never re-implement them.

## Harness

| Function | Does | Post-condition |
|---|---|---|
| `resetDevice()` | Clears SharedPreferences and secure storage (Keychain survives uninstall on iOS) | Fresh device |
| `launchApp($, {inactivitySeconds})` | `GetIt.I.reset()` → `configureFlavor()` (from `appFlavor`) → `bootstrap()` → mount | App as if opened: splash → route chosen by storage. Calling it again = restarting the app with storage intact |
| `ensureSession()` | Reuses the stored token if it is a JWT with `exp` more than 5 min away; otherwise logs in by API and stores token, email, password, langCode; sets `isFirstTime`, `useBiometrics=false`, `isAuthenticated` | Valid session in storage |
| `launchAt($, entry)` | `bootstrap(home: Dashboard)` → `ensureSession()` → mount → wait for Home → `entry($)` | Flow entry point, no login UI |

## Login routines

| Routine | Pre | Steps | Post |
|---|---|---|---|
| `loginFresh($)` | none | `resetDevice` → `launchApp` → onboarding "Omitir" → email + password → "Iniciar sesión" → deny biometrics if asked | Dashboard / Home |
| `loginFromInactivity($)` | session stored | `launchApp(inactivitySeconds: 5)` → wait for the inactivity screen → `unlockWithPassword` | Dashboard / Home |
| `unlockWithPassword($)` | inactivity screen visible | "Ingresar con contraseña" → password → "Ingresar" | Dashboard / Home |
| `denyBiometricsIfAsked($)` | after tapping login | Taps "No, omitir" if the modal shows within 15 s | Modal closed |

UNITED notes:

- On launch, storage decides the screen: `isFirstTime` false → Onboarding; true + `isAuthenticated` → inactivity screen (`AccountInactivePage`); otherwise `LoginEmailPage`. The flag name is inverted (`true` = already logged in once).
- The biometrics modal shows on **every** password login (`login_provider.dart`, `!useBiometrics`), so the routine handles it as optional.
- The inactivity timer is hardcoded per entrypoint (dev 2000 s, qa 300 s); routines inject their own value through `bootstrap(timer:)`.

## Navigation routines (main flow)

| Routine | UNITED | Finsof-like projects |
|---|---|---|
| `goToHome` | Inicio tab (by icon: labels show only on the selected tab) | same |
| `goToSavings` | Home → "Mis inversiones" card → `PiggyBankPage(initialTab: 1)` (Wallet, Inversiones tab) | `goToPortfolio`: Home → investment portfolio |
| `goToInvestmentDetails` | Wallet → first `InvestmentItem` → `InvestmentDetailsPage` | Portfolio → first investment → details |

`goToInvestmentDetails` fails with a clear message when the test user has no investments ("Aún no hay inversiones.") instead of timing out.

Any new flow whose entry is not covered here gets a new routine in `navigation_routines.dart`, named `goTo<Screen>`, starting from the Dashboard and ending with `waitUntilVisible` on its screen probe.

## Adapting to another project

1. Map each routine to the project's pages and copy (`common/screens.dart`).
2. Keep the routine names and post-conditions, so flow tests and this skill read the same across projects.
3. Write the main flow of the project in the CLAUDE.md **Test variables** table.
