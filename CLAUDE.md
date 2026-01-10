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

Note: For device builds, add `-destination 'platform=iOS,name=<device>'`. For simulator: `-destination 'platform=iOS Simulator,name=iPhone 16'`.

## Architecture

### Two-Target Structure

The app has two targets that share code via the `Shared/` directory:

1. **CraftShare (Main App)** - Settings/onboarding UI where users configure API credentials
2. **ShareExtension** - The share sheet UI invoked from Safari

Both targets must include all files from `Shared/` in their target membership.

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
