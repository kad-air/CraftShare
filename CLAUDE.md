# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CraftShare is an iOS Share Extension that saves web pages to Craft Collections using Google's Gemini AI to map webpage content to user-defined schemas.

## Build Commands

```bash
# Build main app (Debug)
xcodebuild -scheme CraftShare -configuration Debug build

# Build main app (Release)
xcodebuild -scheme CraftShare -configuration Release build

# Build share extension
xcodebuild -scheme ShareExtension -configuration Debug build

# Clean build
xcodebuild -scheme CraftShare clean
```

Note: For device builds, add `-destination 'platform=iOS,name=<device>'`. For simulator: `-destination 'platform=iOS Simulator,name=iPhone 15'`.

## Architecture

### Two-Target Structure

The app has two targets that share code via the `Shared/` directory:

1. **CraftShare (Main App)** - Settings/onboarding UI where users configure API credentials
2. **ShareExtension** - The share sheet UI invoked from Safari

Both targets must include all files from `Shared/` in their target membership.

### Data Sharing Between Targets

- **App Groups** (`group.kad-air.CraftShare`): Enables UserDefaults sharing between main app and extension
- **Keychain Access Group**: Shares sensitive credentials (API tokens) between targets
- Configuration in `CredentialsManager.swift` - update `suiteName` if changing the App Group ID

### Core Data Flow (Share Extension)

1. `ShareViewController` captures URL from Safari share sheet
2. `ShareView` fetches Craft collections and their schemas via `CraftAPI`
3. User selects a collection → schema is fetched
4. `GeminiAPI` receives webpage content + schema → returns structured JSON matching schema fields
5. `EditItemView` lets user review/edit extracted data
6. `CraftAPI.createItem()` saves to Craft, then `addInitialDocumentContent()` adds URL preview block

### API Integrations

- **Craft Docs API** (`CraftAPI.swift`): Collections, schemas, item creation, document blocks
- **Gemini API** (`GeminiAPI.swift`): Uses `gemini-2.5-flash-lite` model for content extraction

### Credential Storage

- Sensitive (Craft token, Gemini key): iOS Keychain via `KeychainHelper`
- Non-sensitive (Space ID, user guidance): UserDefaults via App Groups

### Schema Property Types

The Craft schema supports: `text`, `date` (YYYY-MM-DD format), `singleSelect`, `multiSelect`, `number`, `url`, `image`. The `EditItemView` renders appropriate controls for each type:
- `multiSelect`: Displays toggleable chips using `FlowLayout` for wrapping; stores values as `[String]` array
