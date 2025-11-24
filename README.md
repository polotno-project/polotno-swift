# Polotno Swift Demo

Native SwiftUI sample app that launches an embedded Polotno editor (React + Vite) inside a `WKWebView`. The app passes JSON design data to the web editor, listens for a save event, and renders the returned preview image in SwiftUI.

## Prerequisites

- Xcode 15+ (iOS 16 deployment target)
- Node.js 18+ and npm

## Project layout

| Path                     | Description                                             |
| ------------------------ | ------------------------------------------------------- |
| `PolotnoSwift/`          | SwiftUI sources, assets, Info.plist, bundled web editor |
| `PolotnoSwift.xcodeproj` | Xcode project ready to open/run                         |
| `web-editor/`            | Vite React app that hosts the Polotno editor            |

## Building the embedded editor

```bash
cd /Users/lavrton/Projects/polotno-swift/web-editor
npm install
npm run build:ios
```

`npm run build:ios` runs `vite build` and copies the output into `PolotnoSwift/Editor/` so Xcode bundles the latest editor.

> **Note:** Set `VITE_POLOTNO_API_KEY` in a `.env` file if you have a custom Polotno API key. The default demo key is fine for local testing.

## Running the iOS app

1. Open `PolotnoSwift.xcodeproj` in Xcode.
2. Select an iOS 16+ simulator or device.
3. Build & run.
4. Tap **Open Editor** to launch the embedded Polotno editor. After tapping **Save & Close**, the editor posts `{ docJson, previewBase64 }` back to Swift via `window.webkit.messageHandlers.editor`. The sheet dismisses and the SwiftUI view renders the returned PNG.

## Data flow

1. Swift keeps the latest design JSON (`currentDocJSON`) and passes it to the web view.
2. `EditorWebView` injects that JSON into the page via `window.__polotnoReceiveInitialDoc(atob(...))`.
3. The React app’s `nativeBridge` module loads the JSON into the Polotno store and exposes a `saveToNative` helper.
4. When the Save button is pressed, the editor serializes the store, rasterizes a PNG preview, and posts it back to Swift.
5. Swift decodes the payload, updates local state, and reuses the returned JSON next time the editor opens.

## Customization ideas

- Replace `SampleDocument.defaultJSON` (Swift) or `sample-doc.json` (web) with your domain data.
- Update the React UI inside `web-editor/src/App.jsx` to add your own panels, presets, or save flows.
- Extend `EditorWebView` to support additional message types (export PDF, track analytics, etc.).
