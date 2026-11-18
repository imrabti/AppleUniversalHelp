//
//  COREHelpViewer.swift
//
//

import SwiftUI
import WebKit

/// The state of a help viewer: the help bundle, the web page rendering it, the current selection and search.
///
/// Create one per help window and pass it to ``COREHelpView``. Call ``navigate(to:)`` to show a page programmatically.
@MainActor
@Observable
public final class COREHelpViewer {
	public let helpBundle:HelpBundle

	/// The page shown by the `WebView`, configured with the help URL scheme handlers.
	public let webPage:WebPage

	/// The URL of the page selected in the table of contents.
	public private(set) var selectedPageURL:URL?

	public var searchText = ""

	var expandedSections:Set<URL> = []
	var columnVisibility:NavigationSplitViewVisibility = .all
	var preferredCompactColumn:NavigationSplitViewColumn = .sidebar
	var isCompact = false

	@ObservationIgnored var openExternalURL:(URL) -> Void = { _ in }
	@ObservationIgnored private var initialPage:HelpPage?
	@ObservationIgnored private var hasPreparedInitialPage = false

	// MARK: -

	public init(helpBundle:HelpBundle, initialPage:HelpPage? = nil) {
		self.helpBundle = helpBundle
		self.initialPage = initialPage

		// The scheme handlers and navigation decider are created before `self` is available,
		// so they reach the viewer through this coordinator.
		let coordinator = Coordinator()

		var configuration = WebPage.Configuration()
		configuration.urlSchemeHandlers = [
			URLScheme("helpbundle")!: COREHelpResourceSchemeHandler(baseURL: helpBundle.url),
			URLScheme("inbuilt")!: COREHelpResourceSchemeHandler(baseURL: helpBundle.url),
			URLScheme("symbol")!: COREHelpSymbolSchemeHandler(),
			URLScheme("function")!: COREHelpFunctionSchemeHandler { [coordinator] in
				coordinator.viewer?.toggleTableOfContents()
			}
		]
		configuration.userContentController.addUserScript(Self.darkModeScript)

		webPage = WebPage(configuration: configuration, navigationDecider: NavigationDecider(coordinator: coordinator))

		coordinator.viewer = self
	}

	// MARK: - Appearance

	/// Help pages and `styles.css` are usually written for a light appearance only. This stylesheet opts every page
	/// into dark mode and, when the system is dark, overrides hard-coded text colors so the content stays readable.
	private static let darkModeStylesheet = """
	:root { color-scheme: light dark; }
	@media (prefers-color-scheme: dark) {
		html, body { background-color: Canvas !important; color: CanvasText !important; }
		p, li, dt, dd, td, th, h1, h2, h3, h4, h5, h6, span, div, blockquote, figcaption, label, strong, em, b, i {
			color: inherit !important;
		}
		a, a * { color: LinkText !important; }
		table, td, th, hr { border-color: rgba(255, 255, 255, 0.2) !important; }
	}
	"""

	/// Injects ``darkModeStylesheet`` before the page renders, so there's no flash of light content.
	private static var darkModeScript:WKUserScript {
		let css = darkModeStylesheet
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "`", with: "\\`")
		let source = """
		(() => {
			const style = document.createElement('style');
			style.textContent = `\(css)`;
			document.documentElement.appendChild(style);
		})();
		"""
		return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
	}

	// MARK: - Navigation

	/// Shows `page` in the viewer, selecting it in the table of contents.
	public func navigate(to page:HelpPage?) {
		guard let page = page else { return }

		select(page)
		searchText = ""
		preferredCompactColumn = .detail

		if webPage.url?.pathComponents != page.url.pathComponents {
			webPage.load(URLRequest(url: page.url))
		}
	}

	/// Called from the table of contents and search result list selection.
	func selectPage(at url:URL?) {
		guard let url = url else {
			selectedPageURL = nil
			return
		}

		navigate(to: helpBundle.page(for: url))
	}

	/// Keeps the table of contents in sync when the user follows links inside a page.
	func webPageURLDidChange(_ url:URL?) {
		guard let page = helpBundle.page(for: url) else { return }
		select(page)
	}

	private func select(_ page:HelpPage) {
		if let section = helpBundle.section(containing: page) {
			expandedSections.insert(section.url)
		}
		selectedPageURL = page.url
	}

	/// Shows the initial page once the viewer appears. On compact widths, nothing is pushed
	/// unless an initial page was requested, so the table of contents stays visible.
	func prepareInitialPage() {
		guard !hasPreparedInitialPage else { return }
		hasPreparedInitialPage = true

		if let initialPage = initialPage {
			navigate(to: initialPage)
			self.initialPage = nil
		}
		else if !isCompact {
			navigate(to: helpBundle.allPages.first)
		}
	}

	var title:String {
		if let url = webPage.url, url.lastPathComponent.hasSuffix("html") {
			return NSLocalizedString((url.lastPathComponent as NSString).deletingPathExtension, comment: "")
		}
		return helpBundle.page(for: selectedPageURL)?.title ?? ""
	}

	// MARK: - History

	var canGoBack:Bool {
		!webPage.backForwardList.backList.isEmpty
	}

	var canGoForward:Bool {
		!webPage.backForwardList.forwardList.isEmpty
	}

	func goBack() {
		guard let item = webPage.backForwardList.backList.last else { return }
		webPage.load(item)
	}

	func goForward() {
		guard let item = webPage.backForwardList.forwardList.first else { return }
		webPage.load(item)
	}

	// MARK: - Table of Contents

	func toggleTableOfContents() {
		if isCompact {
			selectedPageURL = nil
			preferredCompactColumn = .sidebar
		}
		else {
			withAnimation(.spring(duration: 0.4)) {
				columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
			}
		}
	}

	func isExpanded(_ section:HelpSection) -> Binding<Bool> {
		Binding {
			self.expandedSections.contains(section.url)
		} set: { isExpanded in
			if isExpanded {
				self.expandedSections.insert(section.url)
			}
			else {
				self.expandedSections.remove(section.url)
			}
		}
	}

	// MARK: - Search

	var isSearching:Bool {
		!searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var searchResults:[HelpPage] {
		helpBundle.pagesMatchingSearchTerm(searchText)
	}
}

// MARK: - Coordinator

extension COREHelpViewer {
	@MainActor
	final class Coordinator: Sendable {
		weak var viewer:COREHelpViewer?
	}

	/// Opens web and mail links outside the help viewer, and lets help content load in place.
	struct NavigationDecider: WebPage.NavigationDeciding {
		let coordinator:Coordinator

		func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
			guard let url = action.request.url else { return .allow }

			if ["http", "https", "mailto"].contains(url.scheme?.lowercased()) {
				coordinator.viewer?.openExternalURL(url)
				return .cancel
			}

			return .allow
		}
	}
}
