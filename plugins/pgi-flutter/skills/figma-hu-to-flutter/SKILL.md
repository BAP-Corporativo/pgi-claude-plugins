---
name: figma-hu-to-flutter
description: Implement a flow or screen in a Nextline PGI Flutter project (UNITED, FinsofApp and their versions) from the design team's handoff — the HU / user-story document ("HU - <flujo> - Handoff", Google Doc or .md), its row in the flows index spreadsheet (.xlsx), and the Figma nodes it links — reusing the project's existing widgets and creating new ones only when needed. Use this whenever the user shares a Figma link, an HU / historia de usuario / handoff document, or a flow name from the index and asks to implement, build, maquetar, construir, integrar or "pasar a código" a flow, pantalla, estado or componente — even if they only paste a figma.com/design link and say "constrúyelo" or say "implementa el flujo del simulador". This skill wraps Figma's figma-design-to-code guidance with the project's conventions.
---

# Figma + HU → Flutter

The design team delivers each flow as three linked artifacts. This skill turns them into code that follows the project's architecture and reuses its widgets.

| Artifact | What it gives you | What it never gives you |
|---|---|---|
| Flows index (`.xlsx`) | Flow name, description, link to its HU | Implementation details |
| HU handoff doc | Business rules, validations, states, navigation, Figma links per state, semantic tokens | Endpoints, data contracts, values the designers didn't fix |
| Figma nodes | Layout, components, variables, copy, assets | Behavior and business logic |

**The HU is the source of truth for behavior; Figma is the source of truth for visuals.** When they disagree (copy, amounts in mocks), the HU wins and the difference goes in the report.

## Step 0 — Resolve the project

Read `CLAUDE.md`. You need: `package`, the colors class (`UnitedColors` in UNITED), the scaffold widget, the widget catalog path, and where the HU index lives. Anything missing → ask once, then continue.

## Step 1 — Locate the HU

The flows index lives in Google Drive (`HU index` in `CLAUDE.md`; for UNITED: *Integración de Producto - PGI - UNITED.xlsx*). Columns:

| ID | Sprint | Plataforma | Módulo / Épica | Nombre de Feature | Descripción | Documentación |
|---|---|---|---|---|---|---|
| HU-6 | | App | Mi cuenta | Cambio de idioma en la app | … | HU - Cambio de idioma - Handoff.md |

- **User gave a flow name or HU id** → read the index with the Google Drive connector, match `ID` or `Nombre de Feature`, and confirm `Plataforma` contains `App` (rows marked only `Backoffice` are not implemented in the mobile app; `App + Backoffice` → implement only the app part). Then search Drive for the file named in `Documentación` and read it.
- **User gave an HU link or file** → read it directly.
- **User gave only a Figma link** → implement that node, but ask whether an HU exists before inventing behavior.
- **No Google Drive connector in this session** (`/mcp` doesn't list it) → ask the user to paste the HU or export it to the repo; don't guess from the Figma file alone.

## Step 2 — Build the implementation brief

The HU follows a fixed 5-section template. Translate each section with `references/hu-template-mapping.md` into a brief and **show it to the user before writing code**:

```markdown
## Brief: Simulador de inversión
Feature folder: lib/screens/investment_simulator/
Provider: InvestmentSimulatorProvider (state: currency, levels, amount, level, simulation)
Entry points: piggy-bank bottom sheet option "Simular inversión"; in-app notification
   Visibility rule: only if wallet balance > 0 in some currency → check at the entry point
Exit: "Invertir $[monto]" → new-investment flow with amount + currency preloaded
Validations (live): min 20,000 MXN / 1,200 USD / 1,200 EUR → "Debes invertir al menos [min] [divisa]";
   non-numeric → "Solo se aceptan números"; currency change → amount reset to 0.00
States of the result block: empty · loading (4-bar skeleton, delayed) · result · error + "Reintentar" (unlimited)
Performance: level + progress bar recalculated locally (optimistic); only the yield waits for the server
Figma nodes: 10 (selector, 3 result levels, 3 amount-field states, loading, error, button)

Endpoints: GET client/investment/simulator/levels?currency_id= · GET client/investment/simulator?currency_id=&amount=

## Gaps — need an answer before coding
1. `currency_id` for USD and EUR (only MXN = 3 is known) — or an existing currency source in the project.
2. Copy for levels with a forced term ("sin plazo forzoso" only covers term 0); `withdrawal_info` comes
   unlocalized ("360 dias") and the app is bilingual.
3. Does the new-investment flow already accept amount + currency as parameters?
4. `State Layers/Primary/Opacity-16` (#8d4e2a @16%) has no UnitedColors token.
```

Gaps are questions, not guesses. Ask them all in one message. If the user wants to start anyway, implement with a clearly named placeholder (e.g. a repository method with a `// TODO(HU gap 1)` comment) and list it again in the final report.

## Step 2b — Data contract

Follow `references/data-contract.md`: **models from the HU + Figma, DTOs from the endpoint JSON, mappers in between.**

- Endpoint JSON available (pasted by the user, or in the HU) → write DTOs from it.
- Endpoint not ready → ask for the agreed mock JSON, build the DTO from it and serve it with the mock interceptor (`flutter-api-endpoint`, "Mock-first"). Never invent a contract silently.
- Build the "screen value → source" table and add values with no source to the gaps.
- When an endpoint provides values the HU also lists (minimums, thresholds), use the endpoint and report any mismatch.

## Step 3 — Read Figma (cheapest calls first)

1. **Load Figma's guidance first** (the MCP requires it before `get_design_context`): use the `figma-design-to-code` skill if installed, otherwise `get_figma_skill` with `skill://figma/figma-design-to-code/SKILL.md`. Pass `skillNames` as that guidance says.
2. `get_variable_defs` on one full screen → the token set for the whole flow (cheap, no code).
3. `get_design_context` on **one full screen per distinct layout** (e.g. the Control 16 result screen), with `clientFrameworks: flutter`, `clientLanguages: dart`.
4. For the other states listed in the HU, request only the **changed component node** (amount field "bajo el mínimo", result block "error"), not the whole screen again. Process one screen at a time to protect context.
5. `get_screenshot` when you need the visual target for a node you didn't fetch with a screenshot.

The returned code is React + Tailwind. It is a **visual reference**, never code to translate line by line.

## Step 4 — Translate Figma to Flutter

Apply `references/figma-flutter-mapping.md`. The rules that matter most:

- **Ignore presentation chrome:** `.Building Blocks/status-bar`, `Camera Cutout`, the root frame's `Mockup` shadow and corner radius, absolute positions of the frame on the canvas.
- **Colors by token name, not hex:** `Schemes/<Name>` → `<ColorsClass>.<camelCaseName>` (`Schemes/On Surface Variant` → `UnitedColors.onSurfaceVariant`). Use the hex only to confirm. No token in the palette → it is a gap (Step 2), never a raw hex.
- **Typography by role:** `PGI United/<role>/<size>` → `Theme.of(context).textTheme.<role><Size>` when the project's text theme defines it; otherwise the project's text-style helper. A role that exists in neither (e.g. `headline/super small`) → report it.
- **Material 3 components → Material/project widgets**, not SVG pieces. Figma renders some M3 components (progress indicators, dividers, icons) as downloaded SVG segments; build them with Flutter widgets.
- **Assets:** download only real illustrations/images the project doesn't have. Icons → `Icons.*` or the project's existing icon assets.
- **Component descriptions are requirements:** "Selector ultra simple de divisa para el Simulador… MXN por defecto" tells you scope (feature-local) and behavior (default value).

> This deliberately overrides Figma's generic instruction to place every visible SVG asset: in a Flutter app, an M3 component drawn as SVG fragments is replaced by the native widget.

## Step 5 — Reuse ladder for every component

Open the widget catalog (`docs/widget-catalog.md`, or the path in `CLAUDE.md`). If it doesn't exist, build it first from `lib/widgets/widgets.dart` exports (see `references/widget-catalog-format.md`) and commit it with the feature.

For each Figma component, in this order:

1. **Exact match in the catalog** (or a Code Connect mapping returned by `get_design_context`) → use it.
2. **Close match** → extend it with an **optional** parameter that keeps every existing call site unchanged.
3. **Nothing similar** → create it:
   - used by this flow only, or the Figma description scopes it to this flow → `lib/screens/<feature>/widgets/`
   - reusable across flows → `lib/widgets/<group>/`, export it from `widgets.dart`, add it to the catalog.

Record every decision for the report.

## Step 6 — Implement

- Structure, provider, navigation → `flutter-feature-scaffold`.
- Endpoints (once the gap is answered) → `flutter-api-endpoint`.
- Every HU message and Figma copy → `flutter-intl-strings`. HU messages are the exact copy; Figma mock values (`$100,000.00`) are not strings, they're data.

### HU performance rules → provider code

"Optimistic UI" + "show loading only if it isn't instant" + "unlimited retry" translate to: local recalculation on every keystroke, debounced server call, delayed loading flag, and discarding stale responses.

```dart
class InvestmentSimulatorProvider extends ChangeNotifier {
  InvestmentSimulatorProvider({this.initialCurrency = SimulatorCurrency.mxn});

  final SimulatorCurrency initialCurrency;

  final secureRepository = ServiceLocator.getIt<SecureRepositoryImpl>();
  final investmentSimulatorRepository = ServiceLocator.getIt<InvestmentSimulatorRepository>();

  Future<String> _token() async => await secureRepository.token ?? '';

  static const _debounce = Duration(milliseconds: 300);
  static const _loadingDelay = Duration(milliseconds: 250);

  Timer? _debounceTimer;
  Timer? _loadingTimer;
  int _requestId = 0;

  Future<void> init() async {
    _currency = initialCurrency;
    await getLevels();
  }

  // --- Currency ---
  late SimulatorCurrency _currency;
  SimulatorCurrency get currency => _currency;

  Future<void> selectCurrency(SimulatorCurrency currency) async {
    if (_currency == currency) return;
    _currency = currency;
    _resetAmount();                        // HU: currency change resets the amount
    notifyListeners();
    await getLevels();
  }

  // --- Levels (server, loaded once per currency) ---
  bool _isLoadingLevels = false;
  bool get isLoadingLevels => _isLoadingLevels;

  InvestmentLevelsModel? _levels;
  List<InvestmentLevelModel> get levels => _levels?.levels ?? [];

  String? levelsError;

  Future<void> getLevels() async {
    _isLoadingLevels = true;
    notifyListeners();
    try {
      final token = await _token();
      _levels = await investmentSimulatorRepository.getLevels(token, _currency.id);
      levelsError = null;
    } catch (e) {
      _levels = null;
      levelsError = e.toString();
    } finally {
      _isLoadingLevels = false;
      notifyListeners();
    }
  }

  // --- Amount (optimistic, local) ---
  final amountController = TextEditingController();
  double _amount = 0;
  bool _isInvalidInput = false;

  InvestmentLevelModel? get level => _levels?.levelFor(_amount);

  String? get amountError {
    if (_isInvalidInput) return S.current.simulator_numbers_only;
    final minimum = _levels?.minimumAmount ?? 0;
    if (_amount == 0 || minimum == 0) return null;
    return _amount < minimum
        ? S.current.simulator_min_amount(formatAmount(minimum), _currency.code)
        : null;
  }

  void onAmountChanged(String raw) {
    final parsed = formatRawAmount(raw);   // existing helper
    _isInvalidInput = raw.trim().isNotEmpty && parsed == null;
    _amount = parsed ?? 0;
    notifyListeners();                     // level + progress bar update instantly
    _debounceTimer?.cancel();
    if (level == null || amountError != null) {
      _cancelPending();
      _simulation = null;
      return;
    }
    _debounceTimer = Timer(_debounce, getSimulation);
  }

  // --- Simulation (server, debounced) ---
  bool _isCalculating = false;
  bool get isCalculating => _isCalculating;

  SimulationModel? _simulation;
  SimulationModel? get simulation => _simulation;

  String? simulationError;

  bool get validateInvest => level != null && amountError == null && _simulation != null;

  Future<void> getSimulation() async {
    final id = ++_requestId;
    _loadingTimer?.cancel();
    _loadingTimer = Timer(_loadingDelay, () {
      if (id != _requestId) return;
      _isCalculating = true;               // skeleton only if it isn't instant
      notifyListeners();
    });
    try {
      final token = await _token();
      final result = await investmentSimulatorRepository.getSimulation(token, _currency.id, _amount);
      if (id != _requestId) return;        // a newer keystroke won
      _simulation = result;
      simulationError = null;
    } catch (e) {
      if (id != _requestId) return;
      _simulation = null;
      simulationError = e.toString();
    } finally {
      if (id == _requestId) {
        _loadingTimer?.cancel();
        _isCalculating = false;
        notifyListeners();
      }
    }
  }

  void _resetAmount() {
    _cancelPending();
    _amount = 0;
    _isInvalidInput = false;
    amountController.clear();
    _simulation = null;
    simulationError = null;
  }

  void _cancelPending() {
    _requestId++;
    _debounceTimer?.cancel();
    _loadingTimer?.cancel();
    _isCalculating = false;
  }

  @override
  void dispose() {
    _cancelPending();
    amountController.dispose();
    super.dispose();
  }
}
```

`SimulatorCurrency` is a small enum with `code` and `id` (`mxn('MXN', 3)`, …) until gap 1 is answered.

The "Reintentar" button calls `provider.getSimulation()` directly. The level is computed locally from the levels endpoint, so the progress bar never waits for the network.

### HU states → page sections

Only the result block reacts to loading/error; the selector, amount field and tabs stay interactive (HU section 3). Build it as one switch:

```dart
Widget _buildResultBlock(BuildContext context, InvestmentSimulatorProvider provider) {
  if (provider.isCalculating) return const SimulatorResultSkeleton();          // 4 bars
  if (provider.simulationError != null) {
    return SimulatorResultError(onRetry: provider.getSimulation);
  }
  final simulation = provider.simulation;
  if (simulation == null) return Text(S.of(context).simulator_empty_hint); // empty state
  return SimulatorResultCard(simulation: simulation);  // nextLevel == null → no suggestion
}
```

## Step 7 — Report (traceability)

End with:

1. **HU coverage:** each rule/state/navigation line of the HU → where it's implemented (file + method), or `PENDING (gap n)`.
2. **Figma mapping:** each Figma node → widget used, and whether it was **reused / extended / created** (with path).
3. **Tokens:** any token without a palette match, any typography role without a text style.
4. **Differences:** places where Figma mock data or copy contradicted the HU and what you followed.
5. Updated widget catalog entries.

## Anti-patterns

| ❌ Don't | ✅ Do | Why |
|---|---|---|
| Start coding from the Figma link while an HU exists | Read the HU, build the brief, confirm | Figma has no validations, states or navigation rules |
| Fill HU gaps with values from mocks ("$150,001 más" → threshold) | List them as gaps and ask | Mock data is illustrative; in a fintech app a wrong threshold is a business error |
| Translate the React/Tailwind output line by line | Use it as a visual reference; build with project widgets | It has absolute positioning, web semantics and fixed pixel widths |
| `Color(0xFF9E8B81)` | `UnitedColors.onSurfaceVariant` | Colors come from the palette by token name |
| `TextStyle(fontFamily: 'Montserrat', fontSize: 16, ...)` | `textTheme.titleMedium` (or the project's style helper) | Typography tokens map to theme roles |
| Implementing the status bar, camera cutout or Mockup shadow | Skip them | They are device/presentation chrome, not UI |
| Downloading the SVG segments of a progress indicator | Native progress widget styled with tokens | M3 components drawn as SVG fragments aren't assets |
| New widget without checking the catalog | Reuse ladder: exact → extend → create | Duplicate widgets drift apart |
| Changing an existing widget's required params to fit the design | Add an optional parameter with the old behavior as default | Every current call site must keep working |
| Loading spinner/skeleton on every keystroke | Debounce + delayed loading flag + discard stale responses | The HU forbids flicker and requires optimistic UI |
| Blocking the whole page on calculation error | Replace only the result block, keep inputs interactive | HU section 3 |
| `get_design_context` on every state's full screen | Full screen once per layout, then only the changed nodes | Each call costs a lot of context |

## Finish

1. `flutter analyze` passes; run `intl_utils:generate` and build_runner if strings/DTOs changed.
2. Flow test: if the project has `patrol_test/`, follow `flutter-patrol-flows` — create the flow's test (new flow) or update it (change to an existing flow) and run only that flow on the dev flavor. If there is no device or credentials, report it as pending.
3. Start the report with `Skill aplicada: figma-hu-to-flutter`.
4. Deliver the report from Step 7, the flow test result and the open gaps.
