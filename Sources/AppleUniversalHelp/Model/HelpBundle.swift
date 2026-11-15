//
//  HelpBundle.swift
//
//
//  Created by Steven Troughton-Smith on 03/01/2023.
//

import Foundation

public class HelpItem: Hashable, Identifiable {
	public let url:URL

	public var id:URL { url }

	init(url: URL) {
		self.url = url
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(url)
	}

	public static func == (lhs: HelpItem, rhs: HelpItem) -> Bool {
		return lhs.url == rhs.url
	}
}

public class HelpPage: HelpItem {
	public internal(set) var title = "Page"
	public internal(set) var summary = ""
	public internal(set) var tags:[String] = []

    public override init(url: URL) {
		super.init(url: url)
        self.title = NSLocalizedString((url.lastPathComponent as NSString).deletingPathExtension, comment: "")

		let metadataURL = url.appendingPathExtension("json")
		guard let metadataPath = metadataURL.path.removingPercentEncoding else { return }

		if FileManager.default.fileExists(atPath: metadataPath) {
			do {
				let data = try Data(contentsOf: metadataURL)
				let metadata = try JSONDecoder().decode([String:[String]].self, from: data)

				summary = metadata["summary"]?.first ?? ""
				tags = metadata["tags"] ?? []
			}
			catch {

			}
		}
	}
}

public class HelpSection: HelpItem {

	public internal(set) var title = "Section"
	public internal(set) var pages:[HelpPage]

    public override init(url: URL) {
		var _pages:[HelpPage] = []

		let nspath = url.path as NSString

		let data = try! Data(contentsOf: url.appendingPathComponent("index.json"))
		let indices = try! JSONDecoder().decode([String].self, from: data)

		for item in indices {
            let pagePath = nspath.appendingPathComponent(item)

			if FileManager.default.fileExists(atPath: pagePath) {
                _pages.append(HelpPage(url:URL(fileURLWithPath: pagePath)))
			}
			else {
				NSLog("[HELP] Missing page \(pagePath)")
			}
		}

		pages = _pages
		super.init(url: url)
        title = NSLocalizedString(url.lastPathComponent, comment: "")
	}

}

public struct HelpBundle {
	private let identifier = UUID()

	public let url:URL
	public let rootItems:[HelpItem]

	public init(url:URL) {
		self.url = url

		var _rootItems:[HelpItem] = []

		let data = try! Data(contentsOf: url.appendingPathComponent("index.json"))
		let indices = try! JSONDecoder().decode([String].self, from: data)

		let nspath = url.path as NSString
		for item in indices {
            let itemPath = nspath.appendingPathComponent(item)

            if item.hasSuffix("html") {
				if FileManager.default.fileExists(atPath: itemPath) {
                    _rootItems.append(HelpPage(url:URL(fileURLWithPath: itemPath)))
				}
				else {
					NSLog("[HELP] Missing item \(itemPath)")
				}
			}
			else {
				var isDirectory = ObjCBool(booleanLiteral: false)
				FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory)

				if isDirectory.boolValue == true {
                    _rootItems.append(HelpSection(url:URL(fileURLWithPath: itemPath)))
				}
			}
		}

		rootItems = _rootItems
	}

	/// Loads `Help_<languageCode>.help` from the main bundle if present, falling back to `Help.help`.
	public static func main() -> HelpBundle? {
		if let languageCode = Locale.current.language.languageCode?.identifier,
		   let helpResource = Bundle.main.url(forResource: "Help_\(languageCode)", withExtension: "help") {
			return HelpBundle(url: helpResource)
		}

		guard let helpResource = Bundle.main.url(forResource: "Help", withExtension: "help") else { return nil }
		return HelpBundle(url: helpResource)
	}

	// MARK: - Lookup

	/// Every page in the bundle, in table-of-contents order.
	public var allPages:[HelpPage] {
		rootItems.flatMap { item -> [HelpPage] in
			if let section = item as? HelpSection {
				return section.pages
			}
			else if let page = item as? HelpPage {
				return [page]
			}
			return []
		}
	}

	/// Finds the page matching `url`, comparing path components so that differences in URL form are ignored.
	public func page(for url:URL?) -> HelpPage? {
		guard let url = url else { return nil }
		return allPages.first { $0.url.pathComponents == url.pathComponents }
	}

	func section(containing page:HelpPage) -> HelpSection? {
		rootItems.lazy.compactMap { $0 as? HelpSection }.first { $0.pages.contains(page) }
	}

	// MARK: - Search

	func pagesMatchingSearchTerm(_ searchTerm:String) -> [HelpPage] {

		let searchComponents = searchTerm.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
		var results:[HelpPage] = []
		var relevance:[HelpPage:Int] = [:]

		func _matchPage(_ page:HelpPage, tags:[String]) {
			for match in tags {
				for searchComponent in searchComponents {
					if match.localizedCaseInsensitiveContains(searchComponent) {
						if !results.contains(page) {
							results.append(page)
							relevance[page] = 1
						}
						else {
							relevance[page] = (relevance[page] ?? 1) + 1
						}
					}
				}
			}
		}

		for page in allPages {
			let titleComponents = page.title.components(separatedBy: .whitespacesAndNewlines)
			let summaryComponents = page.summary.components(separatedBy: .whitespacesAndNewlines)

			_matchPage(page, tags: titleComponents)
			_matchPage(page, tags: summaryComponents)
			_matchPage(page, tags: page.tags)
		}

		return results.sorted { a, b in
			return (relevance[a] ?? 0) > (relevance[b] ?? 0)
		}
	}
}
