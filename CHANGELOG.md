# Changelog

All notable changes to the **IT PDF** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0+3] - 2026-11-12

### Added
- **Smallpdf-Inspired Friendly UI & Tools Hub:** Redesigned `HomeScreen` (with Quick Tools launchpad and Popular Tools) and `ToolsScreen` (live search, category filter chips, color-coded tactile micro-cards).
- **14 Modular Standalone PDF Studio Tools:** Each tool isolated in its own file under `lib/features/editor/presentation/tools/`:
  - **Compress PDF Studio:** Lossless stream optimization and PDFium DPI re-encoding with live before/after size & percentage savings telemetry.
  - **Merge PDF Studio:** Drag-and-drop `ReorderableListView` queue, per-file page subsets, heterogeneous page sizing, and automatic TOC bookmarks.
  - **Split & Burst Studio:** Custom page ranges, split-every-N-pages chunks, burst-all single-page exports, and visual organizer handoff.
  - **Watermark Studio:** Live page preview canvas, custom presets (`CONFIDENTIAL`, `DRAFT`), color swatches, opacity/size/rotation controls, and page scope selection.
  - **Page Numbers & Bates Studio:** Interactive 6-zone page frame selector, Bates numbering (`EX-{bates}`), cover-page skip, and custom typography.
  - **PDF to Images (PNG):** Native PDFium rendering at 72/150/300 DPI across all or custom pages.
  - **Images to PDF Studio:** Reorderable thumbnail builder with A4/Letter/Fit sizing, orientation, and margin controls.
  - **Protect & Permissions Studio:** Password strength meter, AES-256/AES-128/RC4-128 cipher selection, and 5 granular permission flags.
  - **Unlock / Decrypt PDF:** Authorized password removal to export unrestricted PDFs.
  - **Notebook & Template Studio:** Multi-page Blank, Ruled, Engineering Grid, and Bullet Journal generators with custom paper tints.
  - **Text Extraction Workbench:** Word/char/page telemetry, in-text filter search, clipboard copy, and `.txt` file export.
- **Release Packaging & CI/CD:** Added `codemagic.yaml`, Windows Inno Setup installer (`compile_inno.ps1`, `windows/packaging/installer.iss`), and multi-platform release workflows.

### Fixed
- **Save As 0-Byte File Bug:** Fixed `FilePickerService` and `AnnotationNotifier.burnAnnotationsToFile` so "Save As" writes and validates full PDF bytes cleanly on Windows even when zero draft annotations are present.
- **Home Screen Viewport Overflow:** Fixed horizontal `RenderFlex` overflow in the `Popular Tools` header on narrow viewports.

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
