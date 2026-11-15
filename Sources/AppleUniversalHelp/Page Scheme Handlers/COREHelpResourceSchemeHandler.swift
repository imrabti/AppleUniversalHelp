//
//  COREHelpResourceSchemeHandler.swift
//
//
//  Created by Steven Troughton-Smith on 03/01/2023.
//

import Foundation
import WebKit
import UniformTypeIdentifiers

enum COREHelpError: Error {
	case taskFailedSuccessfully
}

/// Serves files from the help bundle (`helpbundle://`), the app's `styles.css` (`inbuilt://`),
/// and the app icon (`helpbundle://appicon` / `inbuilt://appicon`).
struct COREHelpResourceSchemeHandler: URLSchemeHandler {
	let baseURL:URL?

	func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, any Error> {
		guard let requestURL = request.url else {
			return .failure(URLError(.badURL))
		}

		if requestURL.host == "appicon" {
			// Image rendering must happen on the main actor
			return .rendering(url: requestURL) {
				COREHelpImageRenderer.appIconPNGData()
			}
		}

		let fileURL:URL?
		if requestURL.scheme == "helpbundle" {
			fileURL = baseURL?.appendingPathComponent(requestURL.absoluteString.replacingOccurrences(of: "helpbundle://", with: ""))
		}
		else {
			fileURL = Bundle.main.url(forResource: "styles", withExtension: "css")
		}

		guard let fileURL = fileURL, let data = try? Data(contentsOf: fileURL) else {
			return .failure(URLError(.fileDoesNotExist))
		}

		let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
		return .reply(url: requestURL, mimeType: mimeType, data: data)
	}
}

// MARK: - Helpers

extension AsyncThrowingStream where Element == URLSchemeTaskResult, Failure == any Error {

	static func failure(_ error:any Error) -> Self {
		AsyncThrowingStream { $0.finish(throwing: error) }
	}

	static func reply(url:URL, mimeType:String?, data:Data) -> Self {
		AsyncThrowingStream { continuation in
			continuation.yield(.response(URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)))
			continuation.yield(.data(data))
			continuation.finish()
		}
	}

	/// Produces PNG data on the main actor (where `ImageRenderer` lives) and replies with it.
	static func rendering(url:URL, _ render: @escaping @MainActor @Sendable () -> Data?) -> Self {
		AsyncThrowingStream { continuation in
			let task = Task { @MainActor in
				guard let data = render() else {
					continuation.finish(throwing: URLError(.cannotDecodeContentData))
					return
				}
				continuation.yield(.response(URLResponse(url: url, mimeType: "image/png", expectedContentLength: data.count, textEncodingName: nil)))
				continuation.yield(.data(data))
				continuation.finish()
			}
			continuation.onTermination = { _ in task.cancel() }
		}
	}
}
