# Contributing to IT PDF

Thank you for your interest in contributing to **IT PDF**!

## Development Philosophy
IT PDF is engineered to be an ultra-responsive, clutter-free, privacy-preserving PDF reader and editor across Android, iOS, and Windows.

### Non-Negotiable Standards
1. **File Size Constraints:** Every handwritten Dart file must remain under 800 lines (aim for < 400 lines).
2. **State Management:** Riverpod 3.x must be used for state management. No business logic in UI widgets.
3. **Engine Integrity:** No simulated operations or fake placeholders. Never swallow exceptions silently.
4. **Data Safety:** Atomic write operations with safety backups. Never overwrite or delete user source files without confirmation.
5. **Quality Gate:** All tests must pass, and `flutter analyze` must report zero errors/warnings.

## Workflow
1. Fork and clone the repository.
2. Ensure Flutter 3.44+ and Dart 3.12+ are installed.
3. Run `flutter pub get`.
4. Ensure tests run with `flutter test`.
5. Run `flutter analyze` before committing.
6. Submit a pull request following conventional commit messages (`feat:`, `fix:`, `perf:`, `chore:`, `test:`).
