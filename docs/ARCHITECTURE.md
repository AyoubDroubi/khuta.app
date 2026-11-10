# Architecture

Khuta is a local-first Flutter app (Android). All data lives on the device; there is no account, no server and no network access (the release build does not declare the Internet permission).

## Storage

- One store: Hive CE, behind `mobile/lib/core/database/local_store.dart`. Boxes: `habits`, `settings`, `categories`, `notes`, `focus`, `todos`, `todo_tags`, `journeys`, `goals`, `journal_entries`, `daily_plans`, and `sync_state` (only the local profile entry).
- UI and controllers read and write through `LocalStore`; they never touch Hive boxes directly. A write is durable before the UI treats it as saved.
- Stored shapes change additively (new optional fields with defaults). A breaking change needs a `schemaVersion` entry in `settings`, a one-time migration at start-up and a test that loads a store of the previous version.
- Images live under the app data folder (`covers`, `journey`, `journeys`, `journal`, `todos`, `focus`, plus the profile photo and background at the root).

## Backup and restore

- `BackupService` writes JSON, or a zip (`backup.json` plus `media/…`) when the data references images. It covers habits, notes, focus sessions, to-dos and tags, categories, journeys, goals, journal entries, daily plans, the settings that belong to a backup and the profile. Format id `"app": "streak"` (compatible with the upstream format) plus `"generator": "khuta"`.
- Restore with “replace” also restores settings and the profile and copies images into the app folder, rewriting stored paths. “Merge” keeps this device's settings. Device-only settings (app lock, auto-backup folder, running focus session) are never exported.
- Zip import accepts only images in the known folders, limits entry count and sizes, and ignores everything else.
- `ImportService` reads exports of other apps. `FolderSync` reads backups from a folder you choose; automatic backups keep the latest five files.

## Start-up

`main.dart` initialises the store; `AppStartup` (first frame) restores a running focus session, applies queued widget and focus actions, pulls the shared backup folder, seeds default categories on the first launch, re-arms reminders, refreshes widgets, runs the automatic backup and cleans unused images.

## Island

The island is an isometric scene painted from sprite files in `mobile/assets/island/` (see `tools/island_art/`). Sprite identifiers, file names, pixel sizes and anchors are a contract pinned by `mobile/test/island_pins_test.dart`, so the art can be replaced without touching the ledger or user progress.

## Testing

`flutter test` runs the suite (about 900 tests): model and controller tests, backup round trips, schedule and Hijri rules, time-zone and daylight-saving robustness, accessibility checks (labels, contrast, tap targets) and Arabic layout checks. Opt-in tests regenerate the island art and a year-of-data backup.
