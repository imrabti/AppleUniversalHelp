//
//  COREHelpTableOfContentsView.swift
//
//
//  Created by Steven Troughton-Smith on 02/01/2023.
//

import SwiftUI

/// The sidebar tree of help sections and pages.
struct COREHelpTableOfContentsView: View {
	let viewer:COREHelpViewer
	@Binding var selection:URL?

	var body: some View {
		List(selection: $selection) {
			ForEach(viewer.helpBundle.rootItems) { item in
				if let section = item as? HelpSection {
					DisclosureGroup(isExpanded: viewer.isExpanded(section)) {
						ForEach(section.pages) { page in
							pageRow(page)
						}
					} label: {
						Text(section.title)
					}
				}
				else if let page = item as? HelpPage {
					pageRow(page)
				}
			}
		}
		.listStyle(.sidebar)
	}

	private func pageRow(_ page:HelpPage) -> some View {
		Text(page.title)
			.tag(page.url)
	}
}
