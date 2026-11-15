//
//  COREHelpSearchSpotlightHandler.swift
//  
//
//  Created by Steven Troughton-Smith on 06/01/2023.
//

import Foundation

/**
 Registers the help bundle with the macOS Help menu search field (`NSUserInterfaceItemSearching`).

~~~
 /*  Sample registration & invocation from a SwiftUI client app: */
 struct ContentView: View {
	 @Environment(\.openWindow) private var openWindow
	 @State private var helpSearchHandler: COREHelpSearchSpotlightHandler?

	 var body: some View {
		 MainView()
			 .onAppear {
				 #if os(macOS) || targetEnvironment(macCatalyst)
				 let handler = COREHelpSearchSpotlightHandler(helpBundle: .main()!)

				 /* When a help item is triggered, open the help window on the corresponding page */
				 handler.actionHandler = { page in
					 openWindow(id: COREHelpWindow.defaultID, value: page.url)
				 }

				 handler.registerWithSystem()
				 helpSearchHandler = handler
				 #endif
			 }
	 }
 }
 ~~~

 */
@MainActor
open class COREHelpSearchSpotlightHandler: NSObject {

	var helpBundle:HelpBundle!
	public var actionHandler:(HelpPage) -> Void = { _ in }
	
	// MARK: -
	
	public init(helpBundle: HelpBundle!) {
		self.helpBundle = helpBundle
	}
	
	// MARK: - Registration
	
	public func registerWithSystem() {
		guard let nsApp = NSClassFromString("NSApplication") else { return }
		guard let sharedApplication = nsApp.value(forKeyPath: "sharedApplication") as? AnyObject else { return }
		
		let _ = sharedApplication.perform(NSSelectorFromString("registerUserInterfaceItemSearchHandler:"), with: self)
	}
	
	// MARK: - NSUserInterfaceItemSearching
	
	@objc(searchForItemsWithSearchString:resultLimit:matchedItemHandler:) func searchForItems(withSearch: String, resultLimit: Int, matchedItemHandler: ([Any]) -> Void) {
		
		matchedItemHandler(helpBundle.pagesMatchingSearchTerm(withSearch))
	}
	
	@objc(localizedTitlesForItem:) func localizedTitles(forItem: Any) -> [String] {
		
		if let page = forItem as? HelpPage {
			return [page.title]
		}
		
		return []
	}
	
	@objc(performActionForItem:) func performAction(forItem: Any) {
		if let page = forItem as? HelpPage {
			actionHandler(page)
		}
	}
}
