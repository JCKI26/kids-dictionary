# Kids Dictionary App

A simple, offline English dictionary app for kids aged 10 and under. Built with Flutter so it runs on both Android and iOS from a single codebase.

## What it does

- Search for a word by typing in the search bar.
- Tap any word to see a kid-friendly definition and a simple example sentence.
- Works completely offline once installed.

## Project structure

```
kids_dict_app/
├── android/          # Android-specific files
├── ios/              # iOS-specific files
├── assets/
│   └── dictionary.json   # Starter word list (20 words)
├── lib/
│   ├── database_helper.dart   # SQLite database helper
│   └── main.dart              # App UI (search + word detail)
├── pubspec.yaml
└── README.md
```

## Starter word list

The app ships with 20 sample words in `assets/dictionary.json`:

apple, book, cat, dog, happy, run, sun, water, friend, school, tree, blue, jump, food, bed, car, music, ball, family, smile.

You can replace or expand this list easily.

## How to run

### 1. Install Flutter

Follow the official guide: https://docs.flutter.dev/get-started/install

Make sure these commands work:

```bash
flutter doctor
flutter --version
```

### 2. Get dependencies

Open a terminal in `kids_dict_app/` and run:

```bash
flutter pub get
```

### 3. Run on an emulator or device

**Android:**

```bash
flutter run
```

Make sure you have an Android emulator open or an Android phone connected with USB debugging enabled.

**iOS (macOS only):**

```bash
flutter run
```

You need Xcode installed and an iOS simulator open or an iPhone connected.

### 4. Build a release version

**Android APK:**

```bash
flutter build apk --release
```

**Android App Bundle (for Google Play):**

```bash
flutter build appbundle --release
```

**iOS:**

```bash
flutter build ios --release
```

## How to add your own words

1. Open `assets/dictionary.json`.
2. Add entries in this format:

```json
{
  "word": "your_word",
  "definition": "A simple explanation a 10-year-old can understand.",
  "example": "A short sentence using the word."
}
```

3. Save the file.
4. Delete the app from the emulator/device and run it again so the database is re-created with the new list.

## Next features you could add

- Text-to-speech pronunciation.
- Pictures for each word.
- Favorites list.
- Daily word reminder.
- Simple quiz game.

## Questions?

Ask Isla to update the word list, add a feature, or explain any part of the code.
