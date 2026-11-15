//
//  COREHelpView.swift
//
//

import SwiftUI
import WebKit

/// The root help view: a sidebar with the table of contents (or search results) beside the rendered help page.
///
/// On iPhone and other compact widths the split view collapses into a navigation stack.
public struct COREHelpView: View {
	@Bindable var viewer:COREHelpViewer

	@Environment(\.openURL) private var openURL
	@Environment(\.isPresented) private var isPresented
	@Environment(\.dismiss) private var dismiss
#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

	@FocusState private var isSearchFocused:Bool

	public init(viewer:COREHelpViewer) {
		self.viewer = viewer
	}

	public var body: some View {
		NavigationSplitView(columnVisibility: $viewer.columnVisibility, preferredCompactColumn: $viewer.preferredCompactColumn) {
			sidebar
				.navigationSplitViewColumnWidth(min: 220, ideal: 300)
		} detail: {
			COREHelpPageView(viewer: viewer)
				.toolbar {
					if showsDoneButton {
						ToolbarItem(placement: .confirmationAction) {
							Button(role: .close) {
								dismiss()
							}
							.keyboardShortcut(.cancelAction)
						}
					}
				}
		}
		.searchable(text: $viewer.searchText, placement: .sidebar, prompt: Text("HELP_TOC_SEARCH_PLACEHOLDER"))
		.searchFocused($isSearchFocused)
		.background {
			// Invisible button that provides ⌘F to focus the search field
			Button("") {
				isSearchFocused = true
			}
			.keyboardShortcut("f", modifiers: .command)
			.hidden()
		}
		.onChange(of: viewer.webPage.url) { _, url in
			viewer.webPageURLDidChange(url)
		}
		.onChange(of: isCompact, initial: true) { _, isCompact in
			viewer.isCompact = isCompact
		}
		.onAppear {
			viewer.openExternalURL = { [openURL] url in
				openURL(url)
			}
			viewer.prepareInitialPage()
		}
	}

	// MARK: -

	@ViewBuilder
	private var sidebar: some View {
		let selection = Binding {
			viewer.selectedPageURL
		} set: { url in
			viewer.selectPage(at: url)
		}

		Group {
			if viewer.isSearching {
				COREHelpSearchResultsView(viewer: viewer, selection: selection)
			}
			else {
				COREHelpTableOfContentsView(viewer: viewer, selection: selection)
			}
		}
		.navigationTitle(Text("HELP_TOC_TITLE"))
	}

	private var isCompact:Bool {
#if os(iOS)
		horizontalSizeClass == .compact
#else
		false
#endif
	}

	private var showsDoneButton:Bool {
#if os(iOS)
		isPresented
#else
		false
#endif
	}
}
