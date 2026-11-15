//
//  COREHelpViewer+Translation.swift
//
//

import SwiftUI
import WebKit

/// In-place translation of the current help page.
///
/// The page's visible text nodes are collected with JavaScript, translated natively with the Translation
/// framework, then written back into the same nodes so the page layout and styling are preserved.
extension COREHelpViewer {
	/// A dedicated content world keeps the translation bookkeeping out of the page's own scripts.
	private static let translationWorld = WKContentWorld.world(name: "COREHelpTranslation")

	/// Returns the trimmed text of every visible text node on the page, in document order.
	///
	/// If the page is already translated, the original text is restored first so that
	/// re-translating always starts from the source content.
	func pageTextSegments() async throws -> [String] {
		let script = """
		let state = window.__coreHelpTranslation;
		if (state) {
			state.nodes.forEach((node, i) => { node.nodeValue = state.originals[i]; });
		}
		else {
			const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
				acceptNode(node) {
					const parent = node.parentElement;
					if (!parent || parent.closest('script, style, noscript, code, pre')) {
						return NodeFilter.FILTER_REJECT;
					}
					return node.nodeValue.trim().length > 0 ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
				}
			});
			const nodes = [];
			while (walker.nextNode()) { nodes.push(walker.currentNode); }
			state = {
				nodes: nodes,
				originals: nodes.map(node => node.nodeValue),
				originalLang: document.documentElement.getAttribute('lang')
			};
			window.__coreHelpTranslation = state;
		}
		return state.originals.map(text => text.trim());
		"""

		let result = try await webPage.callJavaScript(script, contentWorld: Self.translationWorld)
		return result as? [String] ?? []
	}

	/// Replaces the text collected by ``pageTextSegments()`` with `translations`, keeping the
	/// surrounding whitespace of each original text node.
	func applyPageTranslations(_ translations:[String], language:Locale.Language) async throws {
		let script = """
		const state = window.__coreHelpTranslation;
		if (!state || state.nodes.length !== translations.length) { return; }
		state.nodes.forEach((node, i) => {
			const original = state.originals[i];
			const leading = original.match(/^\\s*/)[0];
			const trailing = original.match(/\\s*$/)[0];
			node.nodeValue = leading + translations[i] + trailing;
		});
		document.documentElement.setAttribute('lang', lang);
		"""

		_ = try await webPage.callJavaScript(script, arguments: [
			"translations": translations,
			"lang": language.minimalIdentifier
		], contentWorld: Self.translationWorld)
	}

	/// Restores the page's original, untranslated text.
	func restoreOriginalPageText() async throws {
		let script = """
		const state = window.__coreHelpTranslation;
		if (!state) { return; }
		state.nodes.forEach((node, i) => { node.nodeValue = state.originals[i]; });
		if (state.originalLang === null) {
			document.documentElement.removeAttribute('lang');
		}
		else {
			document.documentElement.setAttribute('lang', state.originalLang);
		}
		"""

		_ = try await webPage.callJavaScript(script, contentWorld: Self.translationWorld)
	}
}
