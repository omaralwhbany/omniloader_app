# Offline localization and fonts

OmniLoader ships with Arabic and English translations and does not need an internet connection to switch languages.

## Languages

- Arabic is the default language and uses right-to-left layout.
- English uses left-to-right layout.
- The selected language is saved locally with SharedPreferences.
- Translation source files are in `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`.

After editing translations, regenerate the Dart localization classes with:

```bash
flutter gen-l10n
```

## Offline font

Aref Ruqaa is bundled under the SIL Open Font License 1.1. The repository stores the font source as base64 text so it can be restored consistently in CI and local Termux builds.

Before running Flutter commands that package assets, restore the font:

```bash
bash scripts/restore_font.sh
flutter pub get
flutter build apk --release
```

The full font license is in `assets/fonts/OFL.txt`.
