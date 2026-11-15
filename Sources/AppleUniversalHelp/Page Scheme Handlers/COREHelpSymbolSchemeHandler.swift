//
//  COREHelpSymbolSchemeHandler.swift
//
//
//  Created by Steven Troughton-Smith on 03/01/2023.
//

import Foundation
import WebKit

/// Serves SF Symbols as PNG images, e.g. `<img src="symbol://star.fill">`.
struct COREHelpSymbolSchemeHandler: URLSchemeHandler {
	func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
		guard let url = request.url, let symbolName = url.host else {
			return .failure(URLError(.badURL))
		}

		return .rendering(url: url) {
			COREHelpImageRenderer.symbolPNGData(named: symbolName)
		}
	}
}
