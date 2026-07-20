<p align="center">
  <img src="ExerciseFinder/Assets.xcassets/AppIcon.appiconset/AppIcon-180.png" width="120" alt="FitS app icon">
</p>

<h1 align="center">FitS</h1>

<p align="center">
  <a href="README.en.md">English</a> · <a href="README.md">简体中文</a>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2017%2B-0A84FF">
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-35C3D6">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-34C759"></a>
</p>

FitS is a local-first exercise browser and workout tracker built with SwiftUI. It combines bilingual exercise information, terminology-aware search, favorites, alternative exercise recommendations, and date-based workout logging.

> FitS is currently a prototype. Exercise instructions and recommendations are provided for informational purposes only and are not a substitute for advice from a physician, physical therapist, or qualified trainer.

## Features

- Search exercise names, equipment, body parts, and target muscles in English or Chinese, including professional terminology and common aliases
- Filter 1,324 exercises by body part and equipment
- View exercise animations, target muscles, secondary muscles, and bilingual instructions
- Discover alternatives based on target muscle, body part, and movement characteristics
- Save favorites and use list swipe actions to favorite an exercise or add it to today's workout
- Log exercises by date with free-form notes for weight, repetitions, and sets
- Attach photos, duplicate an entire workout, or move a workout session to another date
- Export an exercise detail page as a long image through the system share sheet

## Screenshots

| Exercise browser | Exercise details |
|:---:|:---:|
| <img src="docs/screenshots/actions.png" width="280" alt="Exercise browser"> | <img src="docs/screenshots/exercise-detail.png" width="280" alt="Exercise details"> |
| **Alternative exercises** | **Workout history** |
| <img src="docs/screenshots/alternatives.png" width="280" alt="Alternative exercises"> | <img src="docs/screenshots/training-records.png" width="280" alt="Workout history"> |

## Requirements

- macOS with Xcode
- An iOS 17 or newer simulator or device

## Run the project

```bash
git clone https://github.com/summerlyr/FitS.git
cd FitS
open ExerciseFinder.xcodeproj
```

In Xcode, select the `ExerciseFinder` scheme and an iOS simulator, then run the app. The project has no third-party package dependencies. To run on a physical device, select your own development team under Signing & Capabilities.

## Data and privacy

FitS does not require an account and currently does not upload workout data to a server. Favorites, workout records, and workout photos remain in the app's local container. Deleting the app also deletes this local data.

## Dataset and media

Exercise metadata and multilingual instructions are derived from [`hasaneyldrm/exercises-dataset`](https://github.com/hasaneyldrm/exercises-dataset) and have been adapted with additional Chinese terminology, exercise names, and search aliases.

Exercise images and GIFs are **© Gym visual — https://gymvisual.com/**. These assets are not covered by this project's MIT License, and public availability or attribution does not itself grant downstream users a media license. Review Gym visual's terms and obtain any permission required for your intended use or redistribution.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for complete attribution and licensing details.

## Contributing

Bug reports, translation corrections, search aliases, and focused improvements are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before contributing. Report security issues privately as described in [SECURITY.md](SECURITY.md).

## License

Original FitS source code is available under the [MIT License](LICENSE). Third-party data and media are not relicensed by this project; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
