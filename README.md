# AppleUniversalHelp

This library is a work in progress, unsupported, and not currently intended for production. The APIs and implementations therein may change at any time to support my internal & external projects.

A SwiftUI help viewer for iOS, iPadOS and macOS (26 and later). It renders a `.help` bundle with WebKit's SwiftUI `WebView`, alongside a sidebar table of contents and search.

## Usage

Add the help window to your app:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        COREHelpWindow(helpBundle: .main()!)
    }
}
```

Open it with `openWindow(id: COREHelpWindow.defaultID)`, or `openWindow(id: COREHelpWindow.defaultID, value: page.url)` to open a specific page.

To embed or present the viewer yourself (for example in a sheet), create a `COREHelpViewer` and pass it to `COREHelpView`:

```swift
@State private var helpViewer = COREHelpViewer(helpBundle: .main()!)

.sheet(isPresented: $showingHelp) {
    COREHelpView(viewer: helpViewer)
}
```

`HelpBundle.main()` loads `Help_<languageCode>.help` from the main bundle, falling back to `Help.help`.

## Help page URL schemes

| Scheme | Purpose |
| --- | --- |
| `helpbundle://path` | A file relative to the help bundle |
| `helpbundle://appicon` / `inbuilt://appicon` | The app icon as PNG |
| `inbuilt://…` | The app's `styles.css` |
| `symbol://name` | An SF Symbol rendered as PNG |
| `function://…` | Toggles the table of contents |

For a sample app, see [AppleUniversalHelpViewer](https://github.com/steventroughtonsmith/AppleUniversalHelpViewer)
