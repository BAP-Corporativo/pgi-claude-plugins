# Patrol setup (once per project)

Reference implementation: UNITED (`United/UnitedApp`, branch `feat/patrol-flows`). Copy its `patrol_test/common/` and `patrol_test/routines/` and adapt the project-specific values.

## 1. Dependencies — `pubspec.yaml`

```bash
flutter pub add dev:patrol
```

Then add `integration_test` by hand and the `patrol:` block (top level):

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  patrol: ^4.10.0

patrol:
  app_name: <APP>
  flavor: <project>Dev            # default when --flavor is omitted
  android:
    package_name: <applicationId>  # android/app/build.gradle
  ios:
    bundle_id: <PRODUCT_BUNDLE_IDENTIFIER>  # ios/Runner.xcodeproj/project.pbxproj
```

Install the CLI: `dart pub global activate patrol_cli` → `~/.pub-cache/bin/patrol`. Check with `patrol doctor`.

## 2. Android — `android/app/build.gradle`

```groovy
defaultConfig {
    testInstrumentationRunner "pl.leancode.patrol.PatrolJUnitRunner"
    testInstrumentationRunnerArguments clearPackageData: "true"
}
testOptions {
    execution "ANDROIDX_TEST_ORCHESTRATOR"
}
dependencies {
    androidTestUtil "androidx.test:orchestrator:1.5.1"
}
```

`clearPackageData` gives every test file a clean app; the harness restores the session by API, so it costs nothing.

Create `android/app/src/androidTest/java/<package/path>/MainActivityTest.java` (package = the `MainActivity` package): copy it from UNITED and change the `package` line. `MainActivity` must stay a `FlutterFragmentActivity` (local_auth).

## 3. iOS — `RunnerUITests` target

Create the target with the `xcodeproj` gem (ships with CocoaPods) instead of editing `project.pbxproj` by hand:

1. `ios/RunnerUITests/RunnerUITests.m`:
   ```objc
   @import XCTest;
   @import patrol;
   @import ObjectiveC.runtime;

   PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
   ```
2. Ruby script (run from `ios/`) that: creates a `:ui_test_bundle` target `RunnerUITests` (iOS = Podfile platform, language objc) depending on `Runner`; adds the `.m` file; on every build configuration sets `TEST_TARGET_NAME=Runner`, `PRODUCT_BUNDLE_IDENTIFIER=<bundle>.RunnerUITests`, `GENERATE_INFOPLIST_FILE=YES`, `CODE_SIGN_STYLE=Automatic`, `DEVELOPMENT_TEAM` copied from Runner; and adds the target as a testable in the `<project>Dev` and `<project>Qa` schemes (`Xcodeproj::XCScheme::TestAction::TestableReference`). `project.new_target` creates one configuration per project configuration, so flavor configs like `Debug-unitedDev` are covered.
3. `ios/Podfile`, inside `target 'Runner'`:
   ```ruby
   target 'RunnerUITests' do
     inherit! :complete
   end
   ```
4. `cd ios && pod install`.
5. Validate: `patrol build ios --simulator --flavor <project>Dev -t patrol_test/flows/login_fresh_test.dart`.

**Xcode 27+ and simulator builds.** If the build fails in `debug_unpack_ios` with `Flutter.framework ... does not contain architectures "arm64 x86_64"`, it is not the test target: Xcode 27's `lipo -verify_arch` accepts a single architecture and Flutter passes two. Even `flutter build ios --simulator` fails. Fix by building the simulator as arm64 only — it does **not** affect physical devices, IPA, TestFlight or the App Store (they use the `iphoneos` SDK, arm64 only); it only drops Intel-Mac simulator support:

- `Runner` and `RunnerUITests`, every configuration: `EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64` (set it with the same `xcodeproj` script).
- `ios/Podfile` `post_install`, inside `target.build_configurations.each`: `config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'x86_64'`, then `pod install`.

If the script fails, give the user the manual Xcode steps: File → New → Target → UI Testing Bundle, name `RunnerUITests`, language Objective-C, replace the generated file with the one above, set the deployment target, add it to the flavor schemes' Test action.

## 4. Testable bootstrap

The app's `mainCommon(timer)` calls `runApp` and registers in GetIt, so a test cannot reuse it. Split it without changing production behavior:

```dart
void mainCommon(int timer) => bootstrap(timer: timer).then(runApp);

Future<Widget> bootstrap({required int timer, Widget? home}) async {
  // everything mainCommon did before runApp
  return MultiProvider(..., child: AppState(..., timer: timer, home: home));
}
```

Thread `home` down to `MyApp` as `home: home ?? <splash>`. `home` lets `launchAt` start straight on the Dashboard; `timer` lets the inactivity routine use a few seconds.

## 5. Harness and routines

Copy from UNITED and adapt:

| File | Adapt |
|---|---|
| `common/flow_test.dart` | nothing — `flowTest()` wraps `patrolTest` and registers the frame callbacks in a zone that captures the app's uncaught async errors |
| `common/test_env.dart` | nothing |
| `common/app_harness.dart` | `configureFlavor()` (Flavor enum values), `launchAt` home widget (Dashboard page) |
| `common/session.dart` | login repository, what the app's login provider stores (token, email, password, prefs flags) |
| `common/screens.dart` | page types and copy of the project |
| `common/flow_steps.dart` | nothing, unless the session-lost / rejected screens differ |
| `routines/login_routines.dart` | onboarding, login fields and biometrics modal copy |
| `routines/navigation_routines.dart` | the main flow: Alcancía (UNITED) or Portafolio (Finsof-like) |

Add `patrol_test/test_env.example.json` (versioned) and to `.gitignore`:

```
patrol_test/test_env.json
patrol_test/_scratch/
```

## 6. CLAUDE.md

Add the **Test variables** table (see SKILL.md Step 0) and the run command to the project's `CLAUDE.md`.
