//
//  COREHelpFunctionSchemeHandler.swift
//
//
//  Created by Steven Troughton-Smith on 03/01/2023.
//

import Foundation
import WebKit

/// Handles `function://` links in help pages by toggling the table of contents.
struct COREHelpFunctionSchemeHandler: URLSchemeHandler {
	let toggleTableOfContents: @MainActor @Sendable () -> Void

	func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
		let toggleTableOfContents = toggleTableOfContents
		Task { @MainActor in
			toggleTableOfContents()
		}

		// Fail the load so the current page stays on screen
		return .failure(COREHelpError.taskFailedSuccessfully)
	}
}
