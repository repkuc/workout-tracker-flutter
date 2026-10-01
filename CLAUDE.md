# CLAUDE.md

## 1. Project

**Workout Diary** is a Flutter app for tracking strength workouts. It targets Android and is published on Google Play (`applicationId lv.repkuc.workoutdiary`). All data lives on the device; there is no backend. The UI is in three languages: Russian, Latvian and English.

Code comments are written in Russian. Keep new comments in the same style and at the same density.

## 2. Architecture

```
lib/
  main.dart        – init WorkoutService + exercise migration, EasyLocalization (ru/lv/en), themes
  models/          – plain Dart classes with toJson()/fromJson()
  services/        – data access + business logic; the only layer that touches SharedPreferences
  pages/           – full screens (StatefulWidget), call services directly
  widgets/         – reusable stateful cards (charts, active-workout banner)
assets/
  exercises/exercises.json   – built-in exercise library (trilingual names + muscleGroup)
  translations/{en,ru,lv}.json
  images/muscles/, sounds/ (rest-timer end), icon/
```

**Flow:** Page → Service (load the whole list from SharedPreferences, change it, save the whole list back) → Page calls `setState`. Nothing sits between pages and services: no state-management package, no repository layer, no DI.

**Navigation:** `MainPage` has 5 bottom tabs inside an `IndexedStack` that is keyed by `context.locale`, so all tabs rebuild when the language changes:
`HomePage` · `ProgramsPage` · `HistoryPage` · `StatisticsPage` · `SettingsPage`.
`ActiveWorkoutBanner` sits above the `NavigationBar`. Other screens open through `Navigator.push(MaterialPageRoute(...))`; named routes are not used.

`StatisticsPage` has 3 inner tabs: `_OverviewTab`, `ProgressPage` (charts), `BodyMeasurementsPage`.

### Models (`lib/models/`)
- `workout_models.dart`: `Workout` → `List<Exercise>` → `List<WorkoutSet>`.
  - `Workout.status` is `'draft'` or `'done'`. Dates are `'YYYY-MM-DD'` strings. Timestamps (`startedAt`, `finishedAt`, `pausedAt`) are ISO-8601 strings.
  - Timer fields: `startedAt`, `pausedAt`, `totalPausedSeconds`, `duration` (seconds, computed on finish with pauses subtracted).
  - `copiedFromWorkoutId` / `Exercise.copiedFromExerciseId` link a workout to the one it was copied from. They drive the "before / after" comparison in the editor.
  - Program link: `programId`, `programWorkoutName`, `programName`. `programName` is a **snapshot** taken at creation, so the badge still shows correctly if the program is later renamed or deleted.
  - `color` (hex string) and `muscleGroups` (keys such as `chest`).
- `program_models.dart`: `TrainingProgram` → `List<ProgramWorkout>` (days) → `List<ProgramExercise>` (name, targetMuscle key, targetSets). These are templates only: no weights or reps.
- `exercise_template.dart`: library entry with `nameRu/nameLv/nameEn`, `muscleGroup`, `isCustom`, and `getName(languageCode)`.
- `body_weight_entry.dart`: `{date, weight}`.
- `body_measurement_entry.dart`: date plus nullable neck/shoulders/chest/waist/hips/bicep/forearm/thigh/calf, and `getByKey(key)` for the chart chips.

### Services (`lib/services/`)
| Service | Storage key | Notes |
|---|---|---|
| `WorkoutService` | `wt.workouts.v1` (one JSON string), `wt.currentWorkoutId.v1` | Singleton. Caches `SharedPreferences`. Exposes `ValueNotifier<int> dataChanged`, which is bumped on every `saveAllWorkouts`. Handles CRUD for workouts, exercises and sets; timer start/pause/resume; finish; `copyWorkout`; and stats queries (`getVolumeByDateWithName`, `getExerciseProgressByDate`, `getTopExercises`, `getPersonalRecords`, `getLastWorkoutForProgramDay`). |
| `ProgramService` | `wt.programs.v1` | Singleton. CRUD for programs and program days. No change notifier. |
| `ExerciseLibraryService` | `wt.custom_exercises.v1`, `wt.exercises_migrated.v1` | Singleton. Built-in exercises are read from assets and custom ones from prefs. `searchExercises(query, lang, muscleGroup:)`. `migrateExistingExercises()` runs **once** at startup and copies exercise names from history into the custom library. Valid groups: `chest, back, legs, shoulders, arms, abs`. |
| `BodyWeightService` | `body_weight_entries` (a `StringList` of JSON strings) | **Not** a singleton, and an older storage format. One entry per date (upsert), kept sorted in ascending order. |
| `BodyMeasurementService` | `wt.bodyMeasurements.v1` | Singleton. One entry per date (upsert). Sorted newest first. |
| `BackupService` | none | Export: a JSON map `{workouts, bodyWeight, bodyMeasurements, programs}` is written to the temp dir and shared via `share_plus`. Import: `file_picker`. A bare List (the legacy workouts-only format) is also accepted. Workouts and programs merge **by id** (existing ones are skipped). Weight and measurements merge **by date** (upsert). Returns the number of imported workouts. |

## 3. Key patterns

- **Singleton services:** `static final _instance = X._internal(); factory X() => _instance;`. `WorkoutService()` can be called anywhere and returns the same object. (`BodyWeightService` and `BackupService` are not singletons, but they hold no state.)
- **Storage = SharedPreferences + JSON.** Each collection is a single JSON string under a versioned key `wt.<name>.v1`. Every mutation follows the same steps: `loadAll` → find by `indexWhere` → mutate → `saveAll`. Methods return `bool` (false = not found).
- **JSON serialization:** written by hand as `toJson()` / `factory fromJson()`. `fromJson` must stay **backward compatible**: new fields need `?? default` or must be nullable, because old saved data and old backups do not contain them. Numbers are read as `(json['x'] as num).toDouble()`.
- **Backup compatibility:** a new data collection needs a new top-level key in the export, and import must null-check it, so old backups still import and old app versions ignore the new key.
- **Screen refresh:**
  - Pages that show workouts (`HomePage`, `HistoryPage`, `ActiveWorkoutBanner`) subscribe to `WorkoutService().dataChanged` in `initState` and unsubscribe in `dispose`.
  - After pushing a screen that can change data, reload with `Navigator.push(...).then((_) => _load())` or with `await Navigator.push(...); _load();`. **This is the reliable way.**
  - `ProgramsPage` and `ProgramDetailsPage` also call `_load…()` from `didChangeDependencies()`. Don't rely on that alone: it runs after `initState` and when inherited widgets change (for example the locale), **not** on a normal `Navigator.pop()`. The comment in `program_details_page.dart:759` already notes this.
  - Check `if (mounted)` after `await` before calling `setState` or using `context`.
- **Localization:** all UI text goes through `'section.key'.tr()` (easy_localization). Add every new key to **all three** files `assets/translations/{en,ru,lv}.json`. Muscle names use the keys `workout.muscle_<group>`.
- **Muscle values differ by layer:** program templates store muscle *keys* (`chest`). When a workout is created from a template, `Exercise.targetMuscle` gets the *translated text* (`'workout.muscle_chest'.tr()`).
- **Exercise identity in history and stats is the exercise name string**, not an id. Progress charts, PRs, top exercises and "repeat from template" set matching all compare by `name`.
- **Draft workout:** at most one current draft, tracked by `wt.currentWorkoutId.v1`. `createWorkout` and `copyWorkout` set it; `finishWorkout` and `deleteWorkout` clear it.
- **Styling:** dark colours are hardcoded per page (`0xFF0F172A` background, `0xFF1E293B` cards, `0xFFF97316` orange accent) even though `main.dart` defines light and dark themes. Pages build their own header (`_buildHeader()`) instead of using an `AppBar`. UI is split into `_buildX()` methods inside one State class, so the files are large (`workout_editor_page.dart` is about 3,100 lines).
- IDs come from `uuid` v4. Custom exercises use the id format `custom_<millis>`.

## 4. Features

- **Home** (`home_page.dart`): month calendar with days coloured by workout (tap a day for a bottom sheet to view, edit or repeat that workout); stats row; body-weight quick entry; "Start workout" dialog (name, colour, muscle groups); program badge.
- **Workout editor** (`workout_editor_page.dart`): add exercises from the picker; add, edit and delete sets (reps × weight); mark sets and exercises done; workout timer with pause/resume; rest timer with preset chips, vibration and sound (`vibration`, `audioplayers`); rename; finish dialog that warns about incomplete exercises and compares volume and duration with the source workout.
- **Active workout banner** (`widgets/active_workout_banner.dart`): shows the running draft with a live timer above the bottom nav. Tap it to return to the editor.
- **History** (`history_page.dart`): list of workouts with stats and a program badge. A draft opens the editor; a finished workout opens `WorkoutDetailsPage` (read-only, with repeat). Actions: repeat/copy, delete.
- **Statistics** (`statistics_page.dart`):
  - Overview: period filter, totals, top exercises, personal records.
  - Charts (`progress_page.dart`): `VolumeChartCard`, `ExerciseProgressCard` (max weight per exercise over time), `BodyWeightChartCard`, all built with `fl_chart`.
  - Body measurements (`body_measurements_page.dart`): add, edit and delete entries per date, plus a line chart with a chip for each measurement.
- **Exercise library** (`exercise_picker_page.dart`): built-in trilingual list plus custom exercises; search and muscle-group filter; add a custom exercise. It returns an `ExerciseTemplate` through `Navigator.pop`.
- **Training programs** (`programs_page.dart`, `create_program_page.dart`, `program_details_page.dart`): create a program with a schedule and workout days with exercises; edit meta; add or remove days; delete. "Start" a day creates a workout from the template. "Repeat" uses the *current* template exercises and pre-fills sets from the last workout of that day, matched by exercise name. Each day shows the date it was last done.
- **Settings** (`settings_page.dart`): language (ru/lv/en via `context.setLocale`), export/import backup, donate link, app version (`package_info_plus`), privacy policy link (`url_launcher`).

## 5. Technical details

- **Version:** `pubspec.yaml` has `version: 1.2.0+14`. Increase the build number (`+N`) for every Play Store upload.
- **Flutter / Dart:** `pubspec.lock` requires Flutter ≥ 3.38.0 and Dart ≥ 3.10.0. `pubspec.yaml` declares `sdk: ^3.5.3`.
- **Android build** (these are the minimum versions; do not downgrade):
  - Gradle wrapper **8.11.1** (`android/gradle/wrapper/gradle-wrapper.properties`)
  - Android Gradle Plugin **8.9.1** and Kotlin **2.1.0** (`android/settings.gradle`, plugins DSL)
  - Java/JVM target 1.8. `compileSdk`, `minSdk` and `targetSdk` come from the Flutter defaults.
  - `namespace = com.example.workout_diary`, `applicationId = lv.repkuc.workoutdiary`.
  - Groovy build files (`build.gradle`, not `.kts`). `jniLibs useLegacyPackaging true`.
- **Release signing:** `android/key.properties` and `android/*.jks` hold the release key and are gitignored. Never read, print or commit them.
- **Permissions:** `VIBRATE`, `INTERNET`, plus a `<queries>` block for url_launcher.
- **Packages:** `easy_localization`, `shared_preferences`, `uuid`, `fl_chart` (0.69), `path_provider`, `share_plus` (9.x, `Share.shareXFiles`), `file_picker`, `package_info_plus`, `vibration`, `audioplayers`, `url_launcher`, `cupertino_icons`. Dev: `flutter_lints`, `flutter_launcher_icons` (adaptive icon, background `#1F2937`).
- **Tests:** `test/widget_test.dart` is the default counter template. It is out of date and will fail, and there are no real tests.
- Useful commands: `flutter pub get`, `flutter analyze`, `flutter run`, `flutter build appbundle --release`.

## 6. Current tasks

### Done, awaiting on-device testing (branch `claude-code-experiments`, not merged to `main`)
- **Palette unification + button theme fix** (`428b47b`). Changed `workout_editor_page.dart` and the body-weight dialogs in `home_page.dart` / `progress_page.dart` from the old "gray" palette (`1F2937`, `374151` inputs, `Colors.grey[…]` text, 2px dialog borders) to the slate palette (`1E293B`, `0F172A` inputs, `64748B` text, 1px borders). Also removed the editor's `isDark` light/dark branching. In `main.dart`, the `ElevatedButton` theme now uses padding 16×8 and `F97316` in both themes.
  - Test before merging: the editor with the phone in **light system mode** (it should look the same as dark), and the sizes of unstyled dialog confirm and red Delete buttons across the app (they are now smaller).
  - Intentionally left: `374151` as the background of inner panels inside editor dialogs and as the rest-chip border, and `Colors.grey` used for icons, borders and button backgrounds.
- **Samsung Galaxy Z Flip7 overlap fix** (`69903c2`). The add/edit set dialogs now scroll (`SingleChildScrollView`). Validation errors appear as inline `errorText` (via `StatefulBuilder`) instead of snackbars hidden behind the dialog backdrop. Editor snackbars float above the bottom buttons, with a margin based on the measured height of `_bottomButtonsKey`. Test on a foldable or short screen if one becomes available.

### Deferred / planned
1. **Z Flip7 cause #2 (not addressed):** the editor's own `Column` (header + `Expanded` list + `_buildBottomButtons`) overflows when the keyboard shrinks the body on very short or narrow screens (cover screen, landscape, split-screen). The fixed header (~145dp) plus bottom buttons (~120dp) leave no room for the list, so the bottom buttons get drawn over the content.
2. **"Second green" duplication (next task, not started):** `10B981` (success) and `34D399` (volume stat / chart palette) appear side by side in stat rows (`workout_details_page.dart`, `statistics_page.dart`, `history_page.dart`, `home_page.dart`).
3. **Bigger refactor (after the above, not started), in two sub-steps:**
   1. A shared `AppColors` file for the slate palette.
   2. Shared header widgets: one for the main tabs (orange icon box + 22pt title) and one for the sub-pages (back arrow + title).
