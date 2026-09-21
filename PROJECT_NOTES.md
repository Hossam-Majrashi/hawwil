# Hawwil (حوّل) — Project Notes & Architecture Guidelines

## MANDATORY PLATFORM SYNC DIRECTIVE

**CRITICAL RULE FOR ALL FUTURE SESSIONS AND AI ASSISTANTS:**
Any future edit, refactoring, or new feature added to this codebase **MUST be applied across ALL THREE platform screen folders**:
- `lib/screens/mobile/`
- `lib/screens/desktop/`
- `lib/screens/web/`

Never modify or implement a feature in only one screen folder. All three platforms must maintain feature parity and responsive user experiences adapted to their respective form factors.

---

## App Overview
- **App Name:** Hawwil (حوّل - Arabic for "Convert")
- **App ID:** `com.h.hawwil`
- **Purpose:** Seamless bi-directional conversion between MP3 and MP4 with embedded cover art management (ID3 APIC tags), video frame extraction, batch queue conversion, and standalone cover art editor.

## Platform Implementation Details
1. **Desktop (Linux / Windows / macOS):**
   - Shells out to system-installed `ffmpeg` / `ffprobe` via `dart:io` `Process.start` / `Process.run`.
   - Missing binary detection via `which ffmpeg` / `where ffmpeg` with install instructions on setup screen.
   - TagLib metadata via `flutter_taglib`.

2. **Mobile (Android / iOS):**
   - Uses `ffmpeg_kit_flutter_new` for FFmpeg execution.
   - TagLib metadata and Scoped Storage / SAF via `flutter_taglib`.

3. **Web:**
   - Client-side responsive preview and metadata inspection UI.
   - Explanatory banner for native execution vs in-browser conversion.

## Screen Hierarchy
1. **Splash / About:** App identity, Hawwil branding, feature overview.
2. **Language Selection:** Arabic (default/first-class RTL) and English (LTR).
3. **Theme Selection:** Dark (`#212327`, icons/buttons `#232627`) and Light (`#efeef1`, icons/buttons `#fefefe`).
4. **Home:** Main dashboard with Create Project, Cover Art Editor, and Settings.
5. **Create Project:** Single or batch file picker, thumbnail extraction, direction detection, custom cover selection, resolution & bitrate configuration.
6. **Progress:** Real-time queue, per-item and overall progress, cancel/retry.
7. **Cover Art Editor:** Independent MP3 cover inspection, replacement, removal, and tag editing without conversion.
8. **Settings:** Defaults for resolution, bitrates, output folder, language, and theme.
