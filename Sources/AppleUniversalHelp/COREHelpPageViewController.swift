//
//  COREHelpPageViewController.swift
//  
//
//  Created by Steven Troughton-Smith on 02/01/2023.
//

import UIKit
import WebKit

enum COREHelpError: Error {
	case taskFailedSuccessfully
}

class COREHelpPageViewController: UIViewController, WKNavigationDelegate {
	var webView = {
		let config = WKWebViewConfiguration()
		config.setURLSchemeHandler(COREHelpResourceSchemeHandler(), forURLScheme: "helpbundle")
		config.setURLSchemeHandler(COREHelpResourceSchemeHandler(), forURLScheme: "inbuilt")
		config.setURLSchemeHandler(COREHelpSymbolSchemeHandler(), forURLScheme: "symbol")
		config.setURLSchemeHandler(COREHelpFunctionSchemeHandler(), forURLScheme: "function")
		let view = WKWebView(frame: .zero, configuration: config)
		return view
	}()
	
	var baseURL:URL? {
		didSet {
			if let handler = webView.configuration.urlSchemeHandler(forURLScheme: "helpbundle") as? COREHelpResourceSchemeHandler {
				handler.baseURL = baseURL
			}
		}
	}
	
	init() {
		super.init(nibName: nil, bundle: nil)
		
		view.backgroundColor = .systemBackground
		webView.backgroundColor = .clear
		webView.isOpaque = false
		
		webView.navigationDelegate = self
		
		view.addSubview(webView)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// MARK: - Layout
	
	override func viewDidLayoutSubviews() {
		webView.frame = view.bounds
	}
	
	// MARK: - Navigation
	
	func navigate(to page:HelpPage?) {
		guard let page = page else { return }
		webView.load(URLRequest(url: page.url))
		
		title = page.title
	}

	// MARK: - Navigation Delegate

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		
		
		guard let url = navigationAction.request.url else { return }
		
		if url.absoluteString.hasPrefix("http") || url.absoluteString.hasPrefix("https") || url.absoluteString.hasPrefix("mailto:") {
			UIApplication.shared.open(url)
			decisionHandler(.cancel)
		}
		else {
			decisionHandler(.allow)
			
            if url.absoluteString.hasPrefix("html") || url.lastPathComponent.hasSuffix("html") {
                title =  NSLocalizedString((url.lastPathComponent as NSString).deletingPathExtension, comment: "")
				view.window?.windowScene?.title = title
				NotificationCenter.default.post(name: .viewerDestinationChanged, object: url)
			}
		}
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		NotificationCenter.default.post(name: .viewerDestinationChanged, object: nil)
	}
}
