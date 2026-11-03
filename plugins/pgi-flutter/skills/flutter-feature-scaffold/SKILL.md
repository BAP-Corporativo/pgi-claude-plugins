---
name: flutter-feature-scaffold
description: Create a new feature, screen, page, or flow in a Nextline PGI Flutter project (UNITED, FinsofApp and their flavor variants) following the shared architecture — feature folder layout, *Api → *Repository → ChangeNotifier provider, GetIt registration, provider created at the Navigator.push callsite with ..init(), and a StatelessWidget page consuming it via Consumer. Use this whenever the user asks to create, add, scaffold, or build a new feature, module, screen, page, pantalla, flujo, vista, or "nueva sección", or asks to navigate to a new page, wire a provider, or create a ChangeNotifier — even if they only say "crea la pantalla de X" or "agrega el flujo de Y". Also use it when refactoring an existing page that breaks these conventions.
---

# Flutter feature scaffold

Builds a feature end to end in the architecture shared by all Nextline PGI Flutter projects. The patterns are identical across projects; only the package name, paths, and a few widget names change, so resolve those first instead of assuming UNITED's.

## Step 0 — Resolve project values (do this before writing any code)

1. Read the repo's `CLAUDE.md`. If it has a variables table (package, project, flavors), use those values.
2. Otherwise discover them:
   ```bash
   grep '^name:' pubspec.yaml                 # → <package>
   ls lib/main_*_*.dart                       # → <project> prefix and flavors
   ls lib/screens/                            # existing features to mirror
   grep -rl "registerLazySingleton" lib/      # → service locator file
   find lib -name "*_api.dart" | head -3      # → endpoints dir + an Api to mirror
   find lib -name "*_repository.dart" | head -3
   ```
3. **Open the closest existing feature** (in UNITED, `ProductChangeApi` / `ProductChangeRepository` are the canonical reference) and confirm the shapes used below: token received as a parameter, `ApiClient.get/post(path, params:, options:)`, `Dto*Response` + `dto_*_mapper.dart` with `toModel()`, `*Model` exported from `domain.dart`, and the project's scaffold widget (`ScaffoldMain` in UNITED).

## Target layout

```
lib/screens/<feature>/
├── pages/<feature>_page.dart
├── provider/<feature>_provider.dart     # use provider/ or providers/ — whichever the project uses
└── widgets/                             # feature-local widgets only

lib/core/services/network/api/endpoints/<feature>/<feature>_api.dart
lib/core/services/network/dtos/<feature>/dto_<name>_response.dart   (+ .g.dart)
lib/core/services/network/dtos/<feature>/dto_<name>_mapper.dart
lib/core/services/repositories/<feature>/<feature>_repository.dart
lib/domain/<feature>/<name>_model.dart   → exported from lib/domain/domain.dart
```

Shared widgets go in `lib/widgets/` (exported from `widgets.dart`), never inside a feature.

## Worked example: "Beneficiaries" list with a footer button

Backend: `GET client/accounts/{accountId}/beneficiaries` → `{ "items": [ { "id": 1, "name": "...", "bank_name": "...", "account_number": "..." } ] }`

### 1. Domain model — what the provider and UI see

```dart
// lib/domain/beneficiaries/beneficiary_model.dart
class BeneficiaryModel {
  final int id;
  final String name;
  final String accountNumber;
  final String bankName;

  const BeneficiaryModel({
    required this.id,
    required this.name,
    required this.accountNumber,
    required this.bankName,
  });
}
```

Export it from `lib/domain/domain.dart`.

### 2. DTO + mapper — wire format, stays in the networking layer

Create `DtoBeneficiariesResponse` (with a nested `DtoBeneficiary` list) and `dto_beneficiaries_mapper.dart` exposing `List<BeneficiaryModel> toModel()`, following the `flutter-api-endpoint` skill.

### 3. Api — token as parameter, manual Bearer header

```dart
// lib/core/services/network/api/endpoints/beneficiaries/beneficiaries_api.dart
import 'package:dio/dio.dart';
import 'package:united/core/core.dart';

class BeneficiariesApi {
  BeneficiariesApi({required this.apiClient});

  final ApiClient apiClient;

  Future<Response> getBeneficiaries(String token, int accountId) async {
    try {
      final response = await apiClient.get(
        'client/accounts/$accountId/beneficiaries',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}
```

### 4. Repository — returns `*Model`, translates `DioException` into a String

```dart
// lib/core/services/repositories/beneficiaries/beneficiaries_repository.dart
import 'package:dio/dio.dart';
import 'package:united/core/core.dart';
import 'package:united/core/services/network/dtos/beneficiaries/dto_beneficiaries_mapper.dart';
import 'package:united/core/services/network/dtos/beneficiaries/dto_beneficiaries_response.dart';
import 'package:united/domain/domain.dart';

class BeneficiariesRepository {
  BeneficiariesRepository(this.beneficiariesApi);

  final BeneficiariesApi beneficiariesApi;

  Future<List<BeneficiaryModel>> getBeneficiaries(String token, int accountId) async {
    try {
      final response = await beneficiariesApi.getBeneficiaries(token, accountId);
      final dto = DtoBeneficiariesResponse.fromJson(response.data);
      return dto.toModel();
    } on DioException catch (e) {
      if (e.response?.data != null) {
        throw e.response?.data['detail'] ?? 'Error desconocido';
      } else {
        throw ApiError.fromDioError(e).toString();
      }
    }
  }
}
```

### 5. Register in the service locator

```dart
// inside ServiceLocator.setupServiceLocator()
getIt.registerLazySingleton<BeneficiariesApi>(
  () => BeneficiariesApi(apiClient: getIt<ApiClient>()),
);
getIt.registerLazySingleton<BeneficiariesRepository>(
  () => BeneficiariesRepository(getIt<BeneficiariesApi>()),
);
```

Register the Api before the Repository that depends on it, next to similar features.

### 6. Provider — one per page/flow, pulls dependencies from GetIt, reads the token per request

```dart
// lib/screens/beneficiaries/provider/beneficiaries_provider.dart
import 'package:flutter/material.dart';
import 'package:united/core/core.dart';
import 'package:united/domain/domain.dart';
import 'package:united/services/service_locator.dart';

class BeneficiariesProvider extends ChangeNotifier {
  final int accountId;
  BeneficiariesProvider({required this.accountId});

  final secureRepository = ServiceLocator.getIt<SecureRepositoryImpl>();
  final beneficiariesRepository = ServiceLocator.getIt<BeneficiariesRepository>();

  Future<String> _token() async => await secureRepository.token ?? '';

  // --- Load beneficiaries ---
  bool _isLoadingBeneficiaries = false;
  bool get isLoadingBeneficiaries => _isLoadingBeneficiaries;

  List<BeneficiaryModel> _beneficiaries = [];
  List<BeneficiaryModel> get beneficiaries => _beneficiaries;

  String? beneficiariesError;

  // --- Selection ---
  BeneficiaryModel? _selected;
  BeneficiaryModel? get selected => _selected;

  bool get validateSelected => _selected != null;

  final searchController = TextEditingController();

  Future<void> init() async {
    await getBeneficiaries();
  }

  Future<void> getBeneficiaries() async {
    _isLoadingBeneficiaries = true;
    notifyListeners();
    try {
      final token = await _token();
      _beneficiaries = await beneficiariesRepository.getBeneficiaries(token, accountId);
      beneficiariesError = null;
    } catch (e) {
      _beneficiaries = [];
      beneficiariesError = e.toString();
    } finally {
      _isLoadingBeneficiaries = false;
      notifyListeners();
    }
  }

  bool isSelected(BeneficiaryModel beneficiary) => _selected?.id == beneficiary.id;

  void selectBeneficiary(BeneficiaryModel beneficiary) {
    if (_selected?.id == beneficiary.id) return;
    _selected = beneficiary;
    notifyListeners();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
```

Conventions shown here (canonical reference in UNITED: `ProductChangeProvider`):
- Dependencies are `final` fields resolved with `ServiceLocator.getIt<T>()` inside the provider.
- **The token is read on every request** through the private `_token()` helper, never stored in a field (see anti-patterns).
- Each request has its own private loading flag with a getter (`_isLoadingX` / `isLoadingX`) and its own public error (`xError`). The page decides what to show per section.
- On error, reset that request's data (`_beneficiaries = []`) and store `e.toString()` — the repository already throws a readable `String`. Use `catch (e)` so parsing errors are caught too.
- Validation getters are named `validateX`; selection helpers `isSelectedX` / `selectX`.
- The provider owns `TextEditingController`s and disposes them.
- Validation text that lives in the provider uses `S.current.<key>`.

### 7. Navigation — create the provider at the push callsite

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (context) => BeneficiariesProvider(
        accountId: provider.account?.id ?? 0,
      )..init(),
      child: const BeneficiariesPage(),
    ),
  ),
);
```

Constructor parameters (ids, previously selected data) are passed here. `..init()` starts loading as soon as the provider exists.

### 8. Page — StatelessWidget that only consumes

```dart
// lib/screens/beneficiaries/pages/beneficiaries_page.dart
class BeneficiariesPage extends StatelessWidget {
  const BeneficiariesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: Theme.of(context).copyWith(
        dividerTheme: const DividerThemeData(color: Colors.transparent),
      ),
      child: Consumer<BeneficiariesProvider>(
        builder: (context, provider, _) {
          return ScaffoldMain( // the project's scaffold widget
            body: _buildContent(theme, provider, context),
            persistentFooterButtons: [_buildButton(context, provider)],
          );
        },
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    BeneficiariesProvider provider,
    BuildContext context,
  ) {
    if (provider.isLoadingBeneficiaries) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.beneficiariesError != null) {
      return Center(child: Text(provider.beneficiariesError!));
    }
    return ListView.builder(
      itemCount: provider.beneficiaries.length,
      itemBuilder: (context, index) {
        final item = provider.beneficiaries[index];
        return ListTile(
          title: Text(item.name),
          subtitle: Text(item.bankName),
          selected: provider.isSelected(item),
          onTap: () => provider.selectBeneficiary(item),
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, BeneficiariesProvider provider) {
    return ElevatedButton( // use the project's button widget from lib/widgets/
      onPressed: provider.validateSelected ? () => Navigator.pop(context, provider.selected) : null,
      child: Text(S.of(context).continueLabel),
    );
  }
}
```

The outer `Theme` is required whenever the page passes `persistentFooterButtons`: `Scaffold` draws a `Divider` above them, and this hides it. Pages without footer buttons don't need it.

Use the project's localization accessor for every user-facing string (see `flutter-intl-strings`).

## Anti-patterns

| ❌ Don't | ✅ Do | Why |
|---|---|---|
| `ChangeNotifierProvider(create: ...)` inside the page's `build` | Create it in `MaterialPageRoute.builder` at the push callsite | The page must be reusable with a provider configured by the caller; creating it inside rebuilds/recreates state |
| `BeneficiariesProvider(ServiceLocator.getIt<BeneficiariesRepository>())` from a widget | `final _repository = ServiceLocator.getIt<...>()` inside the provider | Convention: dependencies come from GetIt inside the provider, widgets never pass them |
| `Get.to(...)`, `Get.toNamed(...)` | `Navigator.push` / `Navigator.pop` | `GetMaterialApp` is only the root shell; GetX navigation would skip the provider wiring |
| Calling `provider.init()` from `initState` or `addPostFrameCallback` | Chain `..init()` in `create:` | One place starts the flow; avoids double loads on rebuild |
| `StatefulWidget` page holding `TextEditingController`s or loading flags | Put them in the provider; page stays `StatelessWidget` | State lives in one place and survives rebuilds |
| `List<DtoBeneficiary>` or `Response` in the provider | Repository maps to `List<BeneficiaryModel>` via `toModel()` | DTOs never cross above the repository layer |
| Repository returning `bool` and swallowing `DioException` | Throw the translated `detail` / `ApiError` string | The provider needs the backend's reason to show it |
| `context.watch<T>()` scattered through helper methods | One `Consumer<T>` at the top of `build`, pass `provider` down | Matches existing pages; one rebuild boundary |
| A global provider registered at app root for a single flow | One provider per page/flow | No global store in these projects |
| `persistentFooterButtons` without the transparent `dividerTheme` | Wrap `build` in the `Theme` shown above | Otherwise a visible line appears above the buttons |
| `import 'package:<package>/widgets/cards/app_card.dart';` | `import 'package:<package>/widgets/widgets.dart';` | Import through barrels (DTO/mapper files in the repository are the only direct imports) |
| `String? _token;` filled in `init()` and reused by every request | `final token = await _token();` inside each request | The token can change during a long flow; a stale one gets a 401 and the interceptor **forces logout**. Reading secure storage costs milliseconds |
| One shared `isLoading` / `errorMessage` for several requests | One `_isLoadingX` + `xError` per request | A failing preview must not hide an already-loaded list |
| Forgetting `dispose()` for controllers | Dispose every controller in the provider's `dispose` | `ChangeNotifierProvider` calls `dispose` when the route pops |

## Finish

1. If you added DTOs: `flutter pub run build_runner build --delete-conflicting-outputs`.
2. If you added strings: follow `flutter-intl-strings`.
3. Export new shared widgets from `lib/widgets/widgets.dart` (feature-local widgets are not exported).
4. Run `flutter analyze` and fix every issue before reporting done.
5. If the project has `patrol_test/` and the change is a full flow (or modifies one), follow `flutter-patrol-flows` to create or update its flow test and run it on the dev flavor.
6. Tell the user which files were created, where the registration was added, from which callsite the page is pushed, and the flow test result.
