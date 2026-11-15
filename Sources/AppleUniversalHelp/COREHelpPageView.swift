//
//  COREHelpPageView.swift
//
//
//  Created by Steven Troughton-Smith on 02/01/2023.
//

import SwiftUI
import WebKit

/// Renders the current help page with back and forward controls.
struct COREHelpPageView: View {
	let viewer:COREHelpViewer

#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

	var body: some View {
		WebView(viewer.webPage)
			.navigationTitle(viewer.title)
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItemGroup(placement: historyPlacement) {
					Button {
						viewer.goBack()
					} label: {
						Label("Back", systemImage: "chevron.backward")
					}
					.keyboardShortcut("[", modifiers: .command)
					.disabled(!viewer.canGoBack)

					Button {
						viewer.goForward()
					} label: {
						Label("Forward", systemImage: "chevron.forward")
					}
					.keyboardShortcut("]", modifiers: .command)
					.disabled(!viewer.canGoForward)
				}
			}
	}

	/// History buttons sit in the bottom toolbar on iPhone, and beside the title elsewhere.
	private var historyPlacement:ToolbarItemPlacement {
#if os(iOS)
		horizontalSizeClass == .compact ? .bottomBar : .navigation
#else
		.navigation
#endif
	}
}
