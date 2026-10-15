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
- **Styling:** UI colours live in `lib/theme/app_colors.dart` (`abstract final class AppColors`, `static const Color`). New code must use `AppColors.x` instead of hardcoded `Color(0xFF…)` values. Colours are named by meaning, not shade (`background`, `surface`, `accent`, `success`, `volume`, `textMuted`…), so two roles can share a hex but still be separate constants. Not in `AppColors` on purpose: the user-pickable workout palette and the lists that must match it (`home_page.dart` picker + `_workoutColors`, `history_page.dart`, `volume_chart_card.dart`), and chart series lists (`exercise_progress_card.dart`, `body_measurements_page.dart`). Only `Colors.white` / `black` / `transparent` are still used directly; red and greys are `AppColors.danger` (`EF4444`) / `inactive` / `iconNeutral` (`94A3B8`) / `completedButton` / `snackbarNeutral` (`475569`). The app is dark-only (`0F172A` background, `1E293B` cards, `F97316` accent): `main.dart` has a single dark `theme` with `themeMode: ThemeMode.dark`, light status-bar icons are forced via `AnnotatedRegion<SystemUiOverlayStyle>` in `MaterialApp.builder`, and Android `values/styles.xml` uses the same dark native theme as `values-night`. A text field must contrast with what it sits on: inside dialogs and cards (`surface` `1E293B`) use `inputFill` (`0F172A`); directly on a page background (`0F172A`) use `inputFillOnPage` (`1E293B`) — Create program fields, exercise picker search box. Pages build their own header instead of using an `AppBar`. UI is split into `_buildX()` methods inside one State class, so the files are large (`workout_editor_page.dart` is about 3,100 lines).
- **Headers:** new main tabs must use `TabHeader` (`lib/widgets/tab_header.dart`: orange icon box + 22pt title; `icon`, `title`, optional `trailing`, `bottomPadding`). New sub-pages must use `PageHeader` (`lib/widgets/page_header.dart`: 48×48 back `IconButton` + 20pt one-line title; optional `subtitle`, `trailing`, `bottom`, `showDivider`, `onBack`). Back defaults to `Navigator.pop(context)`; pass `onBack` if the page must pop with a result, confirm or save. Exceptions kept on purpose: `HomePage` (22px icon, own layout around the calendar) and `WorkoutEditorPage` (compact header with timer, pause and rest timer).
- **Dialogs:** new dialogs should use `lib/widgets/app_dialog.dart`: `AppDialog` (15pt title with optional 20px icon, compact 16/14 paddings, 1px border — `borderColor` red for delete, green for finish — content always scrollable), `AppDialogCancelButton` / `AppDialogConfirmButton` (13pt, optional `color`), and `appDialogInputDecoration(labelText, hintText, icon, errorText)`. Show validation errors as `errorText` under the field (via `StatefulBuilder`, cleared in `onChanged`), never as a snackbar: it is drawn behind the dialog backdrop. Every dialog text field has a visible `labelText` (small orange label). Used by the workout editor, Home (Start workout, body weight), Charts body weight, Add custom exercise, Create program and Program details dialogs; body measurements dialogs not yet.
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

`main` is merged and pushed to GitHub (`5324f2c`).

### Done and checked on the phone
- **B1: `AppColors` refactor** (`a402731`). ~610 hardcoded `Color(0xFF…)` replaced with `AppColors` constants across 18 files; values unchanged.
- **Colour polish** (`f698d08`). Volume is cyan `22D3EE` everywhere it is shown (stat cards, top exercises, Workout details exercise volume, editor volume chips and finish dialog). Home duration stat → `duration` blue. Statistics PR values → `record` yellow, its "show more" → `accent`. Chart cards moved from Tailwind gray to slate (`1E293B` card, `94A3B8` text, `64748B` labels, `334155` grid, `475569` major lines on both charts). Create program inputs → `inputFill`. Empty-state hints and settings chevron → `textMuted`. `Colors.red` / `Colors.grey[…]` moved into `AppColors` with identical values.
- **Palette unification + button theme fix** (`428b47b`). Editor and body-weight dialogs moved from the old gray palette to slate; editor `isDark` branching removed; `ElevatedButton` theme padding 16×8 and `F97316` in both themes. `panel` (`374151`) has since been removed (editor dialog panels → `surfaceInset`).
- **"Second green" unified** (`538f606`). `34D399` → `10B981` in UI; `34D399` stays only in the workout palette, chart series and the weight-loss badge text.
- **Samsung Galaxy Z Flip7 overlap fix** (`69903c2`). Add/edit set dialogs scroll; inline `errorText` validation; editor snackbars float above the bottom buttons (margin from `_bottomButtonsKey`).
- **Pop-up polish batch 1** (`92912be`). New `AppDialog` shell (`lib/widgets/app_dialog.dart`) used by the set dialogs, Rename workout, Edit exercise, Finish workout, the incomplete-exercises warning and Delete set: 15pt titles, 20px icons, compact paddings, 13pt buttons, inner panels `surfaceInset`; `AppColors.panel` removed. Rename and Edit exercise show "name required" under the field. Translated: timer "paused" label (`workout.paused`), "+1 set" snackbar unit (`workout.reps_unit`), rest-timer chips (`workout.seconds_short` + existing `minutes_short`). Exercise picker muscle tabs draw the images in their own colours (unselected at 50% opacity); unused emoji removed from `_groups`. Dark-only theme in any system mode (see Styling).

### Done, awaiting on-device testing
- **B2: shared header widgets + colour leftovers** (`3f1f6de`). `TabHeader` used by History, Programs, Statistics, Settings (look unchanged). `PageHeader` used by Create program, Exercise picker, Program details (menu button is now an `IconButton`), Workout details (stats block via `bottom`, divider). Titles are 20pt, one line with ellipsis. Home and the workout editor keep their own headers. Colours: `danger` → `EF4444`, `inactive` / `iconNeutral` → `94A3B8`, `completedButton` / `snackbarNeutral` → `475569`, new `chartPill` `334155` for the "show more" pill in `exercise_progress_card.dart`.
- **Compact Add set dialog** (`3d40e14`). Add set and Edit set share `_showSetFormDialog` in `workout_editor_page.dart`.
- **Pop-up polish batch 2 (uncommitted).** Invisible snackbar validation → `errorText` under the field (cleared on typing) in Start workout, body weight on Home and in Charts, Add custom exercise, Create program → add/edit day, Program details → Edit program and add/edit day. These plus Create program → view day, Delete program and Delete day now use `AppDialog`; editing an existing day is titled "Edit workout day" (`programs.edit_workout_day`). Labels added to every unlabelled dialog field (`workout.workout_name`, `programs.program_name_label`, `schedule_label`, `day_name_label`, plus existing `workout.exercise_name` / `target_muscle`). Program details day cards expand on tap to show the day's exercises (name, muscle, sets) with a rotating chevron; buttons inside keep working. Create program cards unchanged (tap already opens the view dialog).

### Next task
**Exercise demo animations.** Decided to use free-exercise-db (github.com/yuhonas/free-exercise-db, Unlicense). Each exercise has 2 photos that the app will alternate (~0.6 s). All 48 built-in exercises are already matched by hand; the mapping table will be provided when that task starts.

### Deferred / planned
1. **Pop-up polish batch 3:** body measurements dialogs (`AppDialog` paddings; delete confirmation wrongly says "Delete workout?"; hardcoded `'см'` unit), one snackbar style in `main.dart` (floating, rounded; "Workout deleted" not in red; translate the hardcoded `'Ошибка:'`), bottom sheets with a drag handle and one shared header layout.
2. **Later:** redraw the muscle images (`assets/images/muscles/`) with a light outline and without the built-in English caption (option B from the picker review).
3. **Z Flip7 cause #2 (not addressed):** the editor's own `Column` (header + `Expanded` list + `_buildBottomButtons`) overflows when the keyboard shrinks the body on very short or narrow screens (cover screen, landscape, split-screen). The fixed header (~145dp) plus bottom buttons (~120dp) leave no room for the list, so the bottom buttons get drawn over the content.
