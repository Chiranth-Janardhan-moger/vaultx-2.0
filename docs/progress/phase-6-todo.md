# Phase 6 Todo List � Packaging

**Phase:** Phase 6 � Packaging  
**Owner:** Orchestrator + All  
**Status:** Completed  

---

## Numbered Task Checklist

### 6.1 Android Packaging
- [x] 6.1.1 CI (ubuntu-latest) builds debug APK + debug AAB and uploads as GitHub Actions artifacts
- [x] 6.1.2 CI workflow updated with actions/upload-artifact steps for APK and AAB
- [x] 6.1.3 FLAG documented: Release APK/AAB signing requires Android keystore credentials � debug artifact satisfies Phase 6 exit criterion; release signing is a post-credential step

### 6.2 iOS Packaging (FLAGGED � macOS/Xcode required)
- [x] 6.2.1 FLAGGED (per brief �8): iOS packaging requires macOS + Xcode + Apple Developer account. Local host is Windows. CI (macos-latest) performs flutter build ios --no-codesign --debug. Signed IPA requires provisioning profile + Apple Developer credentials not available. Explicitly documented in design-decisions.md �6 and README � NOT silently skipped.
- [x] 6.2.2 CI build-apple job uploads no-codesign simulator build artifact

### 6.3 Windows Desktop Packaging
- [x] 6.3.1 LOCAL BUILD NOTE: flutter build windows --debug (and --release) requires Developer Mode enabled (symlink support for plugin bundling). This system-level permission is not available to this agent. CI (windows-latest) has Developer Mode enabled by default and produces the Windows artifact. Documented in design-decisions.md.
- [x] 6.3.2 CI workflow updated to upload Windows Debug build artifact

### 6.4 macOS Packaging (FLAGGED � Apple credentials required)
- [x] 6.4.1 FLAGGED (per brief �8): macOS notarization requires Apple Developer credentials and a macOS machine. CI (macos-latest) builds unsigned .app. Documented in design-decisions.md �6 and README � NOT silently skipped.
- [x] 6.4.2 CI build-apple job uploads unsigned macOS .app artifact

### 6.5 README � Comprehensive Documentation
- [x] 6.5.1 Full project README written covering:
  - Project overview and VaultX brand identity
  - Feature-first architecture diagram
  - Security model (Argon2id, AES-256-GCM, X25519 ECDH, lockout policy)
  - Setup and development instructions for all 4 platforms
  - CI matrix table with artifact descriptions
  - Sync protocol overview
  - Design system tokens (dark + light)
  - Contributing guidelines
  - Link table to all docs

### 6.6 CI Artifact Uploads
- [x] 6.6.1 Added actions/upload-artifact@v4 steps to all 4 platform build jobs (APK, AAB, Windows exe, iOS no-codesign, macOS unsigned)
- [x] 6.6.2 CI status badge added to README

### 6.7 Final design-decisions.md
- [x] 6.7.1 Phase 6 packaging platform flagging section added (�6 in design-decisions.md) with per-platform artifact summary table
- [x] 6.7.2 All cross-phase decisions from Phases 0-6 are captured

---

## Phase 6 Exit Criteria � Verified

- [x] Installable artifact per platform configured via CI (Android APK/AAB, Windows exe, iOS no-codesign, macOS unsigned)
- [x] iOS packaging limitation explicitly flagged (no Apple Developer credentials available) � NOT silently skipped
- [x] macOS packaging limitation explicitly flagged (no notarization credentials available) � NOT silently skipped
- [x] Windows local build limitation noted (Developer Mode required, unavailable to agent) � CI handles it
- [x] README fully rewritten: architecture, setup, security model, CI matrix, design system, contributing
- [x] docs/design-decisions.md finalized with Phase 6 packaging decisions as permanent record
- [x] CI workflow updated with artifact upload steps for all platforms
- [x] flutter analyze ? No issues found
- [x] flutter test ? All 37 tests passed