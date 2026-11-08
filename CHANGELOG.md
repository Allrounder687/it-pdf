# Changelog

All notable changes to the **IT PDF** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-09

### Added
- **Core Architecture:** Clean Feature-First modular architecture with Riverpod 3.x state management.
- **Rendering Foundation:** High-performance PDFium-backed rendering via `pdfrx` with adaptive asynchronous tile/page streaming.
- **Document Library:** Recents, favorites, folder organization, multi-select batch operations, native file picker integration.
- **Reader Engine:** Continuous vertical/horizontal layouts, single/two-page views, pinch-to-zoom, dark/light reading modes, in-document search, bookmarks/outline, page thumbnails.
- **Annotation Engine:** High-precision vector annotations (highlight, underline, strikethrough, ink drawings, shapes, text callouts, sticky notes) with undo/redo and coordinate invariance.
- **Page Organizer & Editor:** Page reordering, rotation, deletion, page extraction, PDF merging, document compilation.
- **Signatures & Forms:** Interactive form field handling, handwritten signature capture with spline smoothing and profile storage.
- **Offline-First Persistence:** Safe atomic file saving, recovery sessions, and local document metadata indexing.
- **Cross-Platform Delivery:** Native Windows desktop adaptive controls, Android and iOS responsive layouts.
- **Automated CI:** GitHub Actions workflows for format checking, static analysis, unit/widget tests, and cross-platform builds.
