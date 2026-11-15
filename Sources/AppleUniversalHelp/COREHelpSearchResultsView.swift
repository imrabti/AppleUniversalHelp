//
//  COREHelpSearchResultsView.swift
//
//
//  Created by Steven Troughton-Smith on 05/01/2023.
//

import SwiftUI

/// Pages matching the current search, ranked by relevance.
struct COREHelpSearchResultsView: View {
	let viewer:COREHelpViewer
	@Binding var selection:URL?

	var body: some View {
		let results = viewer.searchResults

		List(selection: $selection) {
			Section {
				ForEach(results) { page in
					VStack(alignment: .leading, spacing: 4) {
						Text(page.title)
							.font(.headline)
						if !page.summary.isEmpty {
							Text(page.summary)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
					.padding(.vertical, 4)
					.tag(page.url)
				}
			} header: {
				Text("SEARCH_RESULTS")
			}
		}
		.overlay {
			if results.isEmpty {
				ContentUnavailableView.search(text: viewer.searchText)
			}
		}
	}
}
