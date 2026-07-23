# FitS Agent Guide

This file is the project-level handoff for coding agents. Read it before changing
the app. `README.md` is the user-facing Chinese overview and `README.en.md` is
the English version.

## Product

FitS is a local-first SwiftUI exercise browser and workout log for iOS 17+.
The app is bilingual (Simplified Chinese and English), has no account or server,
and currently ships 1,324 exercises and their media in the app bundle.

The core user flow is:

1. Browse or search exercises.
2. Filter by body part and equipment.
3. Read bilingual exercise details and view alternatives.
4. Favorite an exercise or add it to today's workout.
5. Review workouts by list or calendar, then edit, copy, move, photograph, or
   delete a workout.

This is an open-source personal project. Exercise guidance is informational, not
medical advice.

## Repository map

- `ExerciseFinder/ExerciseFinderApp.swift`
  - App entry point, environment stores, tabs, and the default tab.
- `ExerciseFinder/Exercise.swift`
  - Dataset model, localized exercise names, professional term translations,
    and bilingual search aliases.
- `ExerciseFinder/ExerciseStore.swift`
  - Dataset loading, favorites persistence, workout persistence, and workout
    photo storage.
- `ExerciseFinder/ExerciseListView.swift`
  - Exercise/favorites lists, filters, native search integration, workout list,
    calendar, workout detail, and workout editing sheets.
- `ExerciseFinder/ExerciseDetailView.swift`
  - Exercise detail, bilingual detail tabs, alternatives, GIF/image display,
    favorites, and long-image sharing.
- `ExerciseFinder/Localization.swift`
  - App-controlled language switching and the `L10n` helpers.
- `ExerciseFinder/{en,zh-Hans}.lproj/Localizable.strings`
  - UI localization.
- `ExerciseFinder/Resources/data/exercises.json`
  - Bundled exercise dataset.
- `ExerciseFinder/Resources/{images,videos}`
  - Bundled exercise media.
- `project.yml`
  - XcodeGen project definition.
- `ExerciseFinder.xcodeproj`
  - Checked-in Xcode project used to build the app.

There is currently no test target or third-party package dependency.

## Build and validation

Open `ExerciseFinder.xcodeproj`, select the `ExerciseFinder` scheme, and use an
iOS 17+ simulator. Prefer XcodeBuildMCP for agent-driven build, run, logging, and
UI automation when it is available. Do not change the development team or
signing settings merely to make a local build work.

For every code change:

1. Run `git diff --check`.
2. Run `plutil -lint` on any changed `.strings` file.
3. Build the `ExerciseFinder` scheme.
4. For visible changes, run the app and verify the actual interaction, not only
   compilation.
5. Check both languages when text or layout changes.

Useful lightweight syntax check when a full Xcode build is temporarily blocked:

```bash
swiftc -frontend -parse ExerciseFinder/*.swift
```

This is not a substitute for an Xcode build.

For layout-sensitive changes, test at least one narrow iPhone and one large
iPhone. Also check long English titles and Dynamic Type where practical.

## Intentional product and UX decisions

Preserve these behaviors unless the user explicitly requests a change.

### Tabs and search

- Favorites (`收藏`) is the default tab.
- On iOS 18+, Search is a native `Tab(role: .search)` action.
- Tapping Search must only expand the bottom search box. It must not
  programmatically focus the field or open the keyboard.
- Do not set `isSearchPresented = true` or `isSearchFocused = true` when the
  Search tab is selected. SwiftUI treats presentation as activation and opens
  the keyboard.
- The keyboard opens only after the user taps the search field.
- Search covers only exercise name, body part, equipment, and target muscle.
  It intentionally does not search instructions or every dataset field.
- Search keeps the current body-part and equipment filters.
- Search-result detail is presented with a full-screen cover intentionally. This
  preserves query text, search-box state, keyboard state, and scroll position,
  and avoids a tab-bar hide/show flash. Do not replace it with a normal push
  without re-testing all of those behaviors.
- Dismissing active Search returns to the last non-search tab.

### Exercise lists and details

- List exercise names use the primary text color.
- Target muscle appears in list rows and participates in search.
- Favorites are changed from exercise detail or a list swipe action; do not add
  a persistent favorite icon to every row.
- The detail page has no search UI.
- Detail language ordering follows the app language. Dataset English remains the
  source field; Chinese names and terminology are project-added localization.
- Alternative exercises are heuristic recommendations based on exercise data,
  not a manually curated authoritative list.

### Workouts

- A workout session is all entries on the same calendar day.
- Workouts support both calendar and list views, switched from the top-right
  toolbar.
- The calendar supports arrow and horizontal-swipe month navigation.
- Calendar meaning:
  - accent-colored bold number = today;
  - filled circle = selected day;
  - small dot = a day containing a workout.
- Selecting a marked day shows a workout summary, which opens workout detail.
- Workout notes are intentionally free-form text for weight, reps, and sets.
- Copying a workout copies entries and notes, but intentionally does not copy
  photos.
- `删除训练` deletes the whole workout session for that date, including photos,
  after confirmation. Individual exercise entries still have their own delete
  action.

## Localization and exercise data

The app uses an explicit in-app language setting rather than only the system
locale. `LanguageStore` persists the choice, and `L10n` loads the matching
bundle.

When adding UI text:

- Add the English translation to `en.lproj/Localizable.strings`.
- Add or preserve the Simplified Chinese value in
  `zh-Hans.lproj/Localizable.strings` when practical.
- Use existing Chinese source keys and `L10n.string`/`L10n.format` for text
  produced outside normal SwiftUI localization.
- Validate format placeholders in both languages.

For exercise terminology:

- Preserve original dataset fields such as `name`, English instructions, IDs,
  media filenames, and attribution.
- Project-added Chinese names live in `name_zh`; they are not original dataset
  content.
- Add translations and aliases in `ExerciseTerms`, not by overwriting the source
  English field.
- Search aliases should be narrow, professional, and explainable. Avoid broad
  aliases that create many irrelevant results.
- Translation corrections are welcome, but do not claim every term has been
  independently medically verified.

## Persistence

- Favorites are stored in `UserDefaults` as exercise IDs.
- Workout entries and photo metadata are JSON-encoded into `UserDefaults`.
- Workout photo files live under Application Support/`TrainingPhotos`.
- The app is local-only; uninstalling it removes user data.
- There is no schema migration, cloud sync, or export/restore flow yet.

Be careful when changing persisted models. Adding non-optional `Codable` fields
can make existing saved workout data fail to decode. If the model changes,
provide backward-compatible decoding or a migration.

Deleting a workout must keep entry metadata and photo files consistent. Moving
a workout date must move both entries and photo metadata.

## Assets, licenses, and repository hygiene

- Original source code is MIT licensed.
- The exercise dataset has its own attribution/license in `LICENSES/`.
- Gym visual images and GIFs are third-party copyrighted media and are not
  relicensed by the project's MIT license. Read `THIRD_PARTY_NOTICES.md` before
  changing, adding, or redistributing media.
- Do not add new exercise media without a documented source and permission.
- Bundled resources are already large; avoid duplicating media files.
- The active app icon is in `ExerciseFinder/Assets.xcassets/AppIcon.appiconset`.
  `Artwork/FitS-AppIcon.svg` is the README/source artwork. If the real icon is
  intentionally redesigned, update both consistently.
- Preserve unrelated user changes in a dirty worktree. Stage explicit paths.
- Do not commit generated experiments or abandoned icon concepts.

## Current technical limitations

- No automated unit or UI tests.
- Workout persistence silently falls back to empty data when decoding fails.
- The bundled resources are roughly 150 MB, mostly GIFs.
- `ExerciseListView.swift` contains several screens and is large; future
  structural work may split it by feature, but avoid unrelated refactors during
  a focused bug fix.
- App Store privacy-manifest and release-readiness work still need a dedicated
  review.

## Handoff checklist

Before ending an agent task, report:

- user-visible behavior changed;
- files changed;
- build/simulator context used;
- validation performed and any unverified cases;
- whether changes were committed or pushed;
- any unrelated files intentionally left untouched.

