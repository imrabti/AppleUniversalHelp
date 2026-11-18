//
//  COREHelpWindow.swift
//
//
//  Created by Steven Troughton-Smith on 03/01/2023.
//

import SwiftUI

/// A help window scene. Add it to your app's `body`, then open it with
/// `openWindow(id: COREHelpWindow.defaultID)` or, to show a specific page,
/// `openWindow(id: COREHelpWindow.defaultID, value: page.url)`.
///
/// ~~~
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup { ContentView() }
///         COREHelpWindow(helpBundle: .main()!)
///     }
/// }
/// ~~~
public struct COREHelpWindow: Scene {
	public static let defaultID = "com.help.window"

	let id:String
	let helpBundle:HelpBundle

	public init(id:String = COREHelpWindow.defaultID, helpBundle:HelpBundle) {
		self.id = id
		self.helpBundle = helpBundle
	}

	public var body: some Scene {
		WindowGroup(id: id, for: URL.self) { $pageURL in
			COREHelpWindowContent(helpBundle: helpBundle, initialPageURL: pageURL)
		}
#if os(macOS)
		.windowToolbarStyle(.unifiedCompact)
#endif
	}
}

/// Owns a viewer per window, so each window has its own web page and history.
struct COREHelpWindowContent: View {
	@State private var viewer:COREHelpViewer

	init(helpBundle:HelpBundle, initialPageURL:URL?) {
		_viewer = State(initialValue: COREHelpViewer(helpBundle: helpBundle, initialPage: helpBundle.page(for: initialPageURL)))
	}

	var body: some View {
		COREHelpView(viewer: viewer)
	}
}
