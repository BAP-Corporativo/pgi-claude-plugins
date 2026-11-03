# Flow test format

One file per flow: `patrol_test/flows/<flow_snake>_test.dart`. One `patrolTest` per file unless the flow has clearly separate scenarios with the same entry.

## Template

```dart
import '../common/flow_steps.dart';
import '../common/flow_test.dart';
import '../common/screens.dart';
import '../routines/navigation_routines.dart';

void main() {
  flowTest('Flujo <Nombre>: <qué valida>', ($) async {   // never plain patrolTest
    final flow = FlowRunner(
      $,
      name: '<Nombre>',
      entry: goTo<Entry>,              // navigation routine from the Dashboard
      entryProbe: Screens.<entry>,      // proves we are at the entry
    );
    await flow.start();                 // session by API, no login UI

    await flow.step('<acción + resultado esperado>', () async {
      await $('<texto o Key>').tap();
      await $(Screens.<next>).waitUntilVisible();
    }, reached: Checkpoint('<next>', Screens.<next>, reach: goTo<Next>FromEntry));

    await flow.step('<siguiente acción>', () async {
      // ...
    });

    flow.finish();                      // fails the test if any step failed
  });
}
```

## Rules

- **Step = one user action + its assertion.** Name it in Spanish as a behavior: "Abrir pestaña Movimientos", "Confirmar traspaso muestra el resumen".
- **Checkpoint after each screen that is safe to return to.** `reach` is the navigation from the flow entry to that screen; without it, soft restart can only return to the entry.
- **Entry and exit through other flows:** call their navigation routine. Assertions about another flow's screens belong to that flow's test.
- **Wait, don't sleep:** `waitUntilVisible(timeout:)` for network screens (30 s), `pumpAndTrySettle()` after tab switches. Never `Future.delayed` to wait for data.
- **Data dependence:** if the flow needs data the test user may not have (investments, movements), check it and `fail('<qué falta>')` with a clear reason.
- **Side effects:** flows that create real operations (deposits, transfers, requests) only run on dev with amounts and accounts the user approves; stop before the final confirmation unless the user says otherwise.

## Deriving child flows

The main flows are the roots: Home, Alcancía (Wallet) / Portafolio, Detalles de inversión. A child flow starts at its parent's entry:

| Child flow | Entry | First step |
|---|---|---|
| Wallet → Movimientos → detalle | `goToSavings` | tap "Movimientos" tab |
| Detalles → Rendimientos | `goToInvestmentDetails` | tap "Rendimientos" |
| Home → Invertir en {divisa} | `goToHome` | tap the grid option |

If a child flow becomes the entry of other flows, promote its navigation to a `goTo<Screen>` routine.
