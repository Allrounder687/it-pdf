# IT PDF v1.1.0 — Dual-Engine Production Release

### Dual-Engine Architecture
- **Rendering Foundation:** Google PDFium (`pdfrx`) provides hardware-accelerated, sub-16ms 60fps tile rendering, pinch-to-zoom, and smooth continuous scrolling.
- **Document Manipulation Engine:** Syncfusion PDF (`syncfusion_flutter_pdf`) provides true ISO 32000 vector document manipulation, AcroForm field editing, and AES-256 encryption.

### Core Features Added
- **True Vector Page Organizer:** Zero lossy bitmap conversions. Uses vector `PdfTemplate` projection to reorder, rotate (90/180/270/360), delete, and extract pages.
- **ISO 32000 Annotation Burning:** Writes highlights, underlines, strikethroughs, rectangles, ellipses, arrows, and sticky notes directly into PDF streams permanently.
- **Interactive AcroForm Filling & Flattening:** Detects form fields, edits text/checkboxes, and flattens fields to lock submitted data.
- **AES-256 Encryption & Security:** Add password protection with user/owner permissions.
- **Document Outline & Bookmarks:** Full hierarchical table-of-contents navigation drawer.
- **Fast Thumbnail Strip:** Bottom scrub bar for quick visual multi-page browsing.
- **In-Reader Searcher:** Live search highlighting, match counts, and jump-to-result cycling.
- **Grounded AI Assistant:** Provides document summaries, key dates, action items, and grounded Q&A with mandatory `[Page X]` citations.
- **Desktop Drag-and-Drop:** Native file drag-and-drop into reader and library.

### Verified Production Artifacts
- **Windows x64:** `it_pdf_windows_x64.zip`
- **Android APK:** `it_pdf_v1.1.0_android.apk` (81.5 MB)
