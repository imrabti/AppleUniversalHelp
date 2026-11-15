//
//  COREHelpPageView.swift
//
//
//  Created by Steven Troughton-Smith on 02/01/2023.
//

import SwiftUI
import WebKit
import Translation

/// Renders the current help page with back and forward controls.
struct COREHelpPageView: View {
	let viewer:COREHelpViewer

#if os(iOS)
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

	/// Languages offered in the Translate menu, sorted by display name.
	@State private var translationLanguages:[Locale.Language] = []
	/// Drives `translationTask`; setting or invalidating it starts a translation of the current page.
	@State private var translationConfiguration:TranslationSession.Configuration?
	/// The language the page is currently shown in, or `nil` when showing the original text.
	@State private var translatedLanguage:Locale.Language?
	@State private var isTranslating = false

	var body: some View {
		WebView(viewer.webPage)
			.navigationTitle(viewer.title)
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				ToolbarItemGroup(placement: historyPlacement) {
					Button {
						viewer.goBack()
					} label: {
						Label("Back", systemImage: "chevron.backward")
					}
					.keyboardShortcut("[", modifiers: .command)
					.disabled(!viewer.canGoBack)

					Button {
						viewer.goForward()
					} label: {
						Label("Forward", systemImage: "chevron.forward")
					}
					.keyboardShortcut("]", modifiers: .command)
					.disabled(!viewer.canGoForward)
				}

				ToolbarItem(placement: .primaryAction) {
					if isTranslating {
						ProgressView()
							.controlSize(.small)
							.accessibilityLabel("Translating")
					}
					else {
						translateMenu
					}
				}
			}
			.overlay(alignment: .top) {
				if isTranslating {
					translationStatus
						.padding(.top, 12)
						.transition(.move(edge: .top).combined(with: .opacity))
				}
			}
			.animation(.default, value: isTranslating)
			.translationTask(translationConfiguration) { session in
				await translatePage(using: session)
			}
			.task {
				translationLanguages = await Self.supportedTranslationLanguages()
					.sorted { displayName(for: $0).localizedStandardCompare(displayName(for: $1)) == .orderedAscending }
			}
			.onChange(of: viewer.webPage.url?.path) {
				// A newly loaded page always starts out untranslated.
				translatedLanguage = nil
			}
	}

	// MARK: - Translation

	private var translateMenu: some View {
		Menu {
			if translatedLanguage != nil {
				Button("Show Original", systemImage: "arrow.uturn.backward") {
					showOriginal()
				}
				Divider()
			}

			ForEach(translationLanguages, id: \.self) { language in
				Button {
					translate(to: language)
				} label: {
					if language == translatedLanguage {
						Label(displayName(for: language), systemImage: "checkmark")
					}
					else {
						Text(displayName(for: language))
					}
				}
			}
		} label: {
			Label("Translate", systemImage: "translate")
		}
		.disabled(isTranslating || viewer.webPage.url == nil || translationLanguages.isEmpty)
	}

	/// A floating status shown over the page while a translation is in progress.
	private var translationStatus: some View {
		HStack(spacing: 8) {
			ProgressView()
				.controlSize(.small)

			if let target = translationConfiguration?.target {
				Text("Translating to \(displayName(for: target))…")
			}
			else {
				Text("Translating…")
			}
		}
		.font(.callout)
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.glassEffect(.regular, in: .capsule)
		.accessibilityElement(children: .combine)
	}

	private func translate(to language:Locale.Language) {
		if translationConfiguration?.target == language {
			// Same language pairing: re-run the existing session against the current page.
			translationConfiguration?.invalidate()
		}
		else {
			// Leave the source unset so the framework detects the page's language.
			translationConfiguration = TranslationSession.Configuration(source: nil, target: language)
		}
	}

	private func translatePage(using session:sending TranslationSession) async {
		guard let target = translationConfiguration?.target else { return }

		isTranslating = true
		defer { isTranslating = false }

		do {
			let segments = try await viewer.pageTextSegments()
			guard !segments.isEmpty else { return }

			let translations = try await Self.translate(segments, using: session)
			try await viewer.applyPageTranslations(translations, language: target)
			translatedLanguage = target
		}
		catch {
			// pageTextSegments() has already put the original text back, so the page is left untranslated.
			translatedLanguage = nil
			print("[COREHelpPageView] Translation failed: \(error)")
		}
	}

	/// Translates `segments` in a single batch. `TranslationSession` isn't Sendable, so it's used off the main actor.
	private nonisolated static func translate(_ segments:[String], using session:sending TranslationSession) async throws -> [String] {
		let requests = segments.map { TranslationSession.Request(sourceText: $0) }
		// Responses are returned in the same order as the requests.
		return try await session.translations(from: requests).map(\.targetText)
	}

	private func showOriginal() {
		Task {
			try? await viewer.restoreOriginalPageText()
			translatedLanguage = nil
		}
	}

	/// `LanguageAvailability` isn't Sendable, so it's created and queried off the main actor.
	private nonisolated static func supportedTranslationLanguages() async -> [Locale.Language] {
		await LanguageAvailability().supportedLanguages
	}

	private func displayName(for language:Locale.Language) -> String {
		Locale.current.localizedString(forIdentifier: language.minimalIdentifier) ?? language.minimalIdentifier
	}

	// MARK: - Layout

	/// History buttons sit in the bottom toolbar on iPhone, and beside the title elsewhere.
	private var historyPlacement:ToolbarItemPlacement {
#if os(iOS)
		horizontalSizeClass == .compact ? .bottomBar : .navigation
#else
		.navigation
#endif
	}
}
