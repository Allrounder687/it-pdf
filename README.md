# IT PDF 📄⚡

> **A Fast, Minimal-Clutter, Premium Cross-Platform PDF Reader & Editor.**  
> Built for Android, iOS, and Windows using Flutter, Dart, Riverpod, and native PDFium.

---

## 🌟 Overview

**IT PDF** is engineered from the ground up to deliver a clean, desktop-grade and mobile-optimized PDF experience without bloatware, advertisements, or forced cloud telemetry.

### ✨ Key Features
- **High-Performance PDFium Core:** Pixel-perfect anti-aliased rendering, sub-millisecond page caching, and memory-bounded asynchronous decoding.
- **Contextual Reader:** Continuous vertical/horizontal reading, single and two-page viewports, dark reading modes, outline/bookmarks, and in-document search.
- **Precision Annotation Engine:** Highlights, ink drawings with spline smoothing, shapes, arrows, sticky notes, and text callouts with normalized coordinate persistence.
- **Page Organizer & Assembly:** Drag-and-drop page reordering, rotation, deletion, page extraction, and multi-document merging.
- **Form Filling & Signatures:** Interactive field editing and handwritten signature profiles.
- **Offline-First Data Safety:** Atomic file replacement, crash recovery sessions, and local metadata persistence.
- **True Desktop & Mobile Ergonomics:** Windows keyboard shortcuts, responsive sidebars, multi-select operations, and touch/stylus support.

---

## 🏗️ Architecture

IT PDF adheres to **Feature-First Clean Architecture** powered by **Riverpod 3.x**:

```
lib/
├── app/                  # App initialization, routing, themes
├── core/                 # Errors, platform adapters, persistence, logging
├── features/             # Isolated feature slices
│   ├── annotations/      # Vector overlay annotations & persistence
│   ├── editor/           # Document manipulation & merging
│   ├── home/             # Recent documents, continue reading
│   ├── library/          # Folder management, grid/list browsing
│   ├── page_organizer/   # Page grid, reorder, rotate, extract
│   ├── reader/           # PDFium reader viewport & controls
│   ├── scanner/          # Camera & image import to PDF
│   ├── search/           # In-document & library full-text search
│   ├── settings/         # Themes, rendering preferences, cache budget
│   └── signatures/       # Digital ink capture & profile management
└── shared/               # Shared models, widgets, contracts
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.44.0 or newer)
- Dart SDK (v3.12.0 or newer)
- **Windows:** Visual Studio 2022/2026 with C++ Desktop Development tools
- **Android:** Android Studio / SDK 34+
- **iOS:** Xcode 15+ (macOS required)

### Setup & Run
```bash
# Clone the repository
git clone https://github.com/Allrounder687/it-pdf.git
cd it-pdf

# Fetch dependencies
flutter pub get

# Run tests
flutter test

# Run on your current platform (e.g. Windows Desktop)
flutter run -d windows
```

---

## 🧪 Testing & Quality Assurance
Run the automated test suite and linter:
```bash
flutter analyze
flutter test
```

---

## 📄 License
This project is licensed under the [MIT License](LICENSE).
Engine dependencies (PDFium) are licensed under the BSD 3-Clause license.
