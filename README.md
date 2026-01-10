# CraftShare

A Share Extension to save web pages to Craft Collections using Gemini AI to map content to your schema.

## Setup Instructions

Since this project was generated as source files, you need to create an Xcode project to wrap them.

### 1. Create Project
1. Open Xcode.
2. Create a new **App** project.
   - Product Name: `CraftShare`
   - Interface: SwiftUI
   - Language: Swift
3. Save it in `~/Code/CraftShare` (or merge these files into the new project folder).

### 2. Add Share Extension
1. In Xcode, go to **File > New > Target...**
2. Select **Share Extension**.
   - Product Name: `ShareExtension`
3. When asked to "Activate", click **Activate**.

### 3. Add Files
1. Delete the default `ContentView.swift` and `CraftShareApp.swift` created by Xcode in the main app group.
2. Drag the `CraftShare/` folder contents (from this repo) into the `CraftShare` group in Xcode.
3. Delete the default `ShareViewController.swift` created by Xcode in the `ShareExtension` group.
4. Drag the `ShareExtension/` folder contents into the `ShareExtension` group in Xcode.
5. Drag the `Shared/` folder into the project navigator (root level).
   - **Important**: When adding `Shared/`, check the boxes for **BOTH** targets (`CraftShare` and `ShareExtension`) in the "Add to targets" section.

### 4. Configure App Groups (Crucial!)
1. Select the project in the navigator.
2. Select the **CraftShare** target > **Signing & Capabilities**.
3. Click **+ Capability** > **App Groups**.
4. Click **+** to add a new group (e.g., `group.com.yourname.CraftShare`).
5. Select the **ShareExtension** target > **Signing & Capabilities**.
6. Click **+ Capability** > **App Groups**.
7. Check the box for the **SAME** group you just created.
8. Open `Shared/CredentialsManager.swift` and update `static let suiteName` to match your App Group ID.

### 5. Run
1. Select the **CraftShare** scheme and run on your device/simulator.
2. Enter your API Keys (Craft Token, Space ID, Gemini Key).
3. Open Safari, go to a webpage.
4. Tap Share > CraftShare.
