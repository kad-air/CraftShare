# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CraftShare is an iOS Share Extension that saves web pages to Craft Collections using Google's Gemini AI to map webpage content to user-defined schemas.

## Build Commands

```bash
# Build main app (Debug) - ALWAYS use iPhone 17 simulator
xcodebuild -scheme CraftShare -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build main app (Release)
xcodebuild -scheme CraftShare -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17' build

# Build share extension
xcodebuild -scheme ShareExtension -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build

# Clean build
xcodebuild -scheme CraftShare clean
```

**IMPORTANT:** Always use `-destination 'platform=iOS Simulator,name=iPhone 17'` for all debug/test builds. Do NOT use iPhone 16.

## Architecture

### Two-Target Structure

The app has two targets that share code via the `Shared/` directory:

1. **CraftShare (Main App)** - Settings/onboarding UI where users configure API credentials
2. **ShareExtension** - The share sheet UI invoked from Safari

Both targets must include all files from `Shared/` in their target membership.

### Adding New Shared Files to Targets

When creating new files in `Shared/`, you MUST add them to both targets in Xcode:

1. Select the file in Xcode's Project Navigator
2. Open the File Inspector (right panel)
3. Under "Target Membership", check both:
   - ☑ CraftShare
   - ☑ ShareExtension

**Current Shared Files (all need both targets):**
- `APIError.swift` - Unified error types
- `CraftAPI.swift` - Craft API client
- `CredentialsManager.swift` - Credential storage
- `DesignSystem.swift` - Shared UI components (GlassCard, MeshGradientBackground, FlowLayout, MultiSelectView)
- `GeminiAPI.swift` - Gemini AI client
- `KeychainHelper.swift` - Keychain wrapper
- `NetworkConfig.swift` - URLSession configuration

### Data Sharing Between Targets

- **App Groups**: Enables UserDefaults sharing between main app and extension
- **Keychain Access Group**: Shares sensitive credentials (API tokens) between targets
- Configuration in `CredentialsManager.swift` - update `suiteName` if changing the App Group ID

### Core Data Flow (Share Extension)

1. `ShareViewController` captures URL from Safari share sheet
2. `ShareView` fetches Craft collections and their schemas via `CraftAPI`
3. User selects a collection → schema is fetched
4. `GeminiAPI` receives webpage content + schema → returns structured JSON matching schema fields
5. `EditItemView` lets user review/edit extracted data
6. `CraftAPI.createItem()` saves to Craft, then `addInitialDocumentContent()` adds URL preview block

### Credential Storage

- Sensitive (Craft token, Gemini key): iOS Keychain via `KeychainHelper`
- Non-sensitive (Space ID, user guidance): UserDefaults via App Groups

## Craft API Reference

Base URL pattern: `https://connect.craft.do/links/{spaceId}/api/v1`
Auth: Bearer token in `Authorization` header

### Key Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/collections` | GET | List all collections in space |
| `/collections/{id}/schema?format=schema` | GET | Get collection schema with property definitions |
| `/collections/{id}/items` | POST | Create new collection item |
| `/blocks` | POST | Add content blocks (richUrl, image) to a document |

### Schema Response Format

```json
{
  "contentPropDetails": { "key": "title", "name": "Title" },
  "properties": [
    { "key": "status", "name": "Status", "type": "select", "options": [{"name": "Todo"}, {"name": "Done"}] },
    { "key": "dueDate", "name": "Due Date", "type": "date" }
  ]
}
```

### Schema Property Types

Supported types: `text`, `date` (YYYY-MM-DD), `select`/`singleSelect`, `multiSelect`, `number`, `url`, `image`

The `EditItemView` renders appropriate controls for each type:
- `multiSelect`: Toggleable chips using `FlowLayout`; stores values as `[String]` array

### Creating Collection Items

Craft expects a nested structure - the content key (e.g., `title`) at top level, other fields inside `properties`:

```json
{
  "items": [{
    "title": "Page Title",
    "properties": {
      "status": "Todo",
      "dueDate": "2025-01-15"
    }
  }]
}
```

Note: `CraftAPI.createItem()` restructures flat Gemini output into this nested format.

### Adding Document Content

After creating an item, `addInitialDocumentContent()` adds blocks to the document:

```json
{
  "blocks": [
    { "type": "richUrl", "url": "https://..." },
    { "type": "image", "url": "https://...", "markdown": "![](url)" }
  ],
  "position": { "position": "end", "pageId": "{document-id}" }
}
```

## Gemini API

Uses `gemini-2.5-flash-lite` model via `https://generativelanguage.googleapis.com/v1beta/models/`

The prompt includes:
- Schema description with property types and options
- The content key field name (required in output)
- Suggested image URL from OG metadata
- User guidance text (configurable in settings)
- Truncated webpage content (first 100k chars)
