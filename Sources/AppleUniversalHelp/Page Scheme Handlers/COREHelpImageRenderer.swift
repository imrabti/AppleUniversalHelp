//
//  COREHelpImageRenderer.swift
//
//

import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Renders SwiftUI images to PNG data for the help page scheme handlers.
@MainActor
enum COREHelpImageRenderer {

#if os(macOS)
	static let scale:CGFloat = 2
#else
	static let scale:CGFloat = 3
#endif

	static func symbolPNGData(named symbolName:String) -> Data? {
		let symbol = Image(systemName: symbolName)
			.font(.system(size: 32))
			.foregroundStyle(Color.accentColor)

		return pngData(for: symbol)
	}

	static func appIconPNGData() -> Data? {
#if os(macOS)
		let icon = Image(nsImage: NSApplication.shared.applicationIconImage)
			.resizable()
			.frame(width: 128, height: 128)
#else
		guard let iconName = Bundle.main.infoDictionary?["CFBundleIconFile"] as? String else { return nil }
		let icon = Image(iconName)
#endif

		return pngData(for: icon)
	}

	static func pngData(for view:some View) -> Data? {
		let renderer = ImageRenderer(content: view)
		renderer.scale = scale

		guard let cgImage = renderer.cgImage else { return nil }

		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
		CGImageDestinationAddImage(destination, cgImage, nil)
		guard CGImageDestinationFinalize(destination) else { return nil }

		return data as Data
	}
}
